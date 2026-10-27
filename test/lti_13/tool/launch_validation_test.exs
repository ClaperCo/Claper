defmodule Lti13.Tool.LaunchValidationTest do
  use ClaperWeb.ConnCase

  import Claper.AccountsFixtures
  import Claper.EventsFixtures
  import Lti13.RegistrationsFixtures

  alias Lti13.Tool.{LaunchValidation, OidcLogin}
  alias Lti13.Users
  alias Claper.Repo

  @lti "https://purl.imsglobal.org/spec/lti/claim/"

  setup_all do
    key = JOSE.JWK.generate_key({:rsa, 2048})
    {_, public_key} = key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()
    %{key: key, public_key: Map.put(public_key, "kid", "platform-key")}
  end

  setup %{public_key: public_key} do
    {:ok, _} = Claper.Settings.set("lti_enabled", "true")

    registration =
      registration_fixture(%{
        issuer: "https://93.184.216.34",
        key_set_url: "https://93.184.216.34/jwks"
      })

    {:ok, _} =
      Lti13.Deployments.create_deployment(%{registration_id: registration.id, deployment_id: 1})

    event = event_fixture()

    {:ok, _} =
      Lti13.Resources.create_resource(%{
        title: "Existing resource",
        resource_id: 1,
        registration_id: registration.id,
        event_id: event.id
      })

    Req.Test.stub(Lti13.HTTP, fn conn ->
      assert conn.request_path == "/jwks"
      Req.Test.json(conn, %{"keys" => [public_key]})
    end)

    %{registration: registration}
  end

  test "signed attacker claims cannot log in as existing normal or admin accounts", context do
    admin_role =
      Claper.Accounts.get_role_by_name("admin") ||
        elem(Claper.Accounts.create_role(%{name: "admin"}), 1)

    for user <- [user_fixture(), user_fixture(%{role_id: admin_role.id})] do
      {state, nonce} = initiate(context.registration)
      claims = claims(context.registration, nonce, %{"email" => user.email})
      assert {:error, %{reason: :invalid_user}} = launch(context.key, state, claims)

      assert Users.get_user_by_sub_and_registration_id(claims["sub"], context.registration.id) ==
               nil
    end
  end

  test "legacy poisoned mappings require explicit local password approval", context do
    local_user = user_fixture()
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce, %{"email" => local_user.email})

    {:ok, mapping} =
      Users.create_user(%{
        sub: claims["sub"],
        name: claims["name"],
        email: claims["email"],
        roles: claims[@lti <> "roles"],
        user_id: local_user.id,
        registration_id: context.registration.id
      })

    assert {:error, %{reason: :invalid_user}} = launch(context.key, state, claims)
    assert {:ok} = Users.authorize_legacy_user(local_user, mapping.id, valid_user_password())
    {new_state, new_nonce} = initiate(context.registration)

    assert {:ok, %{lti_user: approved}} =
             launch(context.key, new_state, %{claims | "nonce" => new_nonce})

    assert approved.user_id == local_user.id
  end

  test "new identities create distinct local accounts and repeat launches reuse only that binding",
       context do
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce)
    assert {:ok, %{lti_user: first}} = launch(context.key, state, claims)
    assert first.provisioned_at
    assert first.user.email == claims["email"]

    {new_state, new_nonce} = initiate(context.registration)

    assert {:ok, %{lti_user: repeated}} =
             launch(context.key, new_state, %{claims | "nonce" => new_nonce})

    assert repeated.id == first.id
    assert repeated.user_id == first.user_id
    assert repeated.user.role_id == first.user.role_id
  end

  test "state must belong to the initiating browser", context do
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce)
    token = sign(context.key, claims)

    assert {:error, %{reason: :invalid_oidc_state}} =
             LaunchValidation.validate(
               %{"state" => state, "id_token" => token},
               "another-browser"
             )

    assert Users.get_user_by_sub_and_registration_id(claims["sub"], context.registration.id) ==
             nil
  end

  test "unsolicited nonce is rejected before identity creation", context do
    {state, _nonce} = initiate(context.registration)
    claims = claims(context.registration, "not-the-issued-nonce")
    assert {:error, %{reason: :invalid_nonce}} = launch(context.key, state, claims)
    assert Claper.Accounts.get_user_by_email(claims["email"]) == nil
  end

  test "an initiated state and nonce cannot be replayed", context do
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce)
    assert {:ok, _} = launch(context.key, state, claims)
    assert {:error, %{reason: :invalid_nonce}} = launch(context.key, state, claims)
  end

  describe "platform approval" do
    setup context do
      Lti13.Registrations.Registration
      |> Repo.get!(context.registration.id)
      |> Ecto.Changeset.change(approved_at: nil)
      |> Repo.update!()

      %{registration: Lti13.Registrations.get_registration!(context.registration.id)}
    end

    test "pending platforms cannot start an OIDC login", context do
      states_before = Repo.aggregate(Lti13.LaunchStates.LaunchState, :count)

      assert {:error, %{reason: :registration_pending}} =
               OidcLogin.oidc_login_redirect_url(%{
                 "iss" => context.registration.issuer,
                 "client_id" => context.registration.client_id,
                 "login_hint" => "platform-user",
                 "target_link_uri" => "https://tool.example.com/lti/launch"
               })

      assert Repo.aggregate(Lti13.LaunchStates.LaunchState, :count) == states_before
    end

    test "pending platforms cannot launch or provision identities", context do
      # A state issued before the platform's approval was revoked.
      {:ok, challenge} = Lti13.LaunchStates.create(context.registration.id)
      claims = claims(context.registration, challenge.nonce)
      users_before = Repo.aggregate(Claper.Accounts.User, :count)
      resources_before = Repo.aggregate(Lti13.Resources.Resource, :count)

      assert {:error, %{reason: :registration_pending}} =
               launch(context.key, challenge.state, claims)

      assert Repo.aggregate(Lti13.Users.User, :count) == 0
      assert Repo.aggregate(Claper.Accounts.User, :count) == users_before
      assert Repo.aggregate(Lti13.Resources.Resource, :count) == resources_before
      assert Claper.Accounts.get_user_by_email(claims["email"]) == nil
    end

    test "launches work once an administrator approves the platform", context do
      admin_role =
        Claper.Accounts.get_role_by_name("admin") ||
          elem(Claper.Accounts.create_role(%{name: "admin"}), 1)

      admin = user_fixture(%{role_id: admin_role.id})

      assert {:error, :unauthorized} =
               Lti13.Registrations.approve_registration(context.registration, user_fixture())

      assert {:ok, approved} =
               Lti13.Registrations.approve_registration(context.registration, admin)

      assert approved.approved_by_id == admin.id
      {state, nonce} = initiate(approved)
      assert {:ok, %{lti_user: lti_user}} = launch(context.key, state, claims(approved, nonce))
      assert lti_user.provisioned_at

      assert {:ok, revoked} = Lti13.Registrations.revoke_registration(approved, admin)
      refute Lti13.Registrations.approved?(revoked)

      assert {:error, %{reason: :registration_pending}} =
               OidcLogin.oidc_login_redirect_url(%{
                 "iss" => revoked.issuer,
                 "client_id" => revoked.client_id,
                 "login_hint" => "platform-user",
                 "target_link_uri" => "https://tool.example.com/lti/launch"
               })
    end
  end

  test "initiation is bound to its registered platform", context do
    other = registration_fixture(%{key_set_url: "https://93.184.216.34/jwks"})
    {:ok, _} = Lti13.Deployments.create_deployment(%{registration_id: other.id, deployment_id: 1})
    {state, nonce} = initiate(context.registration)
    claims = claims(other, nonce)
    assert {:error, %{reason: :invalid_nonce}} = launch(context.key, state, claims)
    assert Claper.Accounts.get_user_by_email(claims["email"]) == nil
  end

  test "controller refuses forged administrator email without minting any session", context do
    admin_role =
      Claper.Accounts.get_role_by_name("admin") ||
        elem(Claper.Accounts.create_role(%{name: "admin"}), 1)

    victim = user_fixture(%{role_id: admin_role.id})
    {state, nonce} = initiate(context.registration)
    token = sign(context.key, claims(context.registration, nonce, %{"email" => victim.email}))
    before_count = Repo.aggregate(Claper.Accounts.UserToken, :count)

    conn =
      context.conn
      |> init_test_session(%{"state" => state})
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/lti/launch", %{"state" => state, "id_token" => token})

    assert html_response(conn, 200) =~ "Sign in locally"
    assert get_session(conn, :user_token) == nil
    assert get_session(conn, "state") == nil
    assert Repo.aggregate(Claper.Accounts.UserToken, :count) == before_count
  end

  test "controller creates a session only for a safely provisioned identity", context do
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce)

    conn =
      context.conn
      |> init_test_session(%{"state" => state})
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
      |> post(~p"/lti/launch", %{"state" => state, "id_token" => sign(context.key, claims)})

    assert redirected_to(conn) =~ "/e/"
    session_user = Claper.Accounts.get_user_by_session_token(get_session(conn, :user_token))
    assert session_user.email == claims["email"]
    mapping = Users.get_user_by_sub_and_registration_id(claims["sub"], context.registration.id)
    assert mapping.user_id == session_user.id
    assert mapping.provisioned_at
  end

  test "LMS administrator roles never grant the local admin role", context do
    {state, nonce} = initiate(context.registration)

    claims =
      claims(context.registration, nonce, %{
        (@lti <> "roles") => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator"]
      })

    assert {:ok, %{lti_user: user, resource: resource}} = launch(context.key, state, claims)
    refute Claper.Accounts.user_has_role?(user.user, "admin")

    leader =
      resource.event_id
      |> Claper.Events.get_activity_leaders_for_event()
      |> Enum.find(&(&1.email == user.email))

    assert leader.user_id == user.user_id
  end

  test "signed multi-audience claims must authorize this tool's client", context do
    {state, nonce} = initiate(context.registration)

    claims =
      claims(context.registration, nonce, %{
        "aud" => [context.registration.client_id, "another-tool"],
        "azp" => "another-tool"
      })

    assert {:error, %{reason: :invalid_audience}} = launch(context.key, state, claims)
    assert Claper.Accounts.get_user_by_email(claims["email"]) == nil
  end

  defp initiate(registration) do
    {:ok, state, url} =
      OidcLogin.oidc_login_redirect_url(%{
        "iss" => registration.issuer,
        "client_id" => registration.client_id,
        "login_hint" => "platform-user",
        "target_link_uri" => "https://tool.example.com/lti/launch"
      })

    query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    {state, query["nonce"]}
  end

  defp claims(registration, nonce, overrides \\ %{}) do
    Map.merge(
      %{
        "iss" => registration.issuer,
        "aud" => registration.client_id,
        "sub" => Ecto.UUID.generate(),
        "name" => "Platform User",
        "email" => unique_user_email(),
        "given_name" => "Platform",
        "family_name" => "User",
        "nonce" => nonce,
        "iat" => System.system_time(:second) - 1,
        "exp" => System.system_time(:second) + 300,
        (@lti <> "deployment_id") => "1",
        (@lti <> "message_type") => "LtiResourceLinkRequest",
        (@lti <> "version") => "1.3.0",
        (@lti <> "roles") => ["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
        (@lti <> "resource_link") => %{"id" => "1", "title" => "Resource"},
        (@lti <> "context") => %{"label" => "Course", "title" => "Course"},
        (@lti <> "custom") => %{"resource_id" => "1", "resource_title" => "Resource"},
        "https://purl.imsglobal.org/spec/lti-ags/claim/endpoint" => %{
          "lineitems" => "https://93.184.216.34/lineitems"
        }
      },
      overrides
    )
  end

  defp launch(key, state, claims),
    do: LaunchValidation.validate(%{"state" => state, "id_token" => sign(key, claims)}, state)

  defp sign(key, claims) do
    {_, token} =
      key
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "platform-key"}, claims)
      |> JOSE.JWS.compact()

    token
  end
end
