defmodule ClaperWeb.Lti.LaunchControllerTest do
  use ClaperWeb.ConnCase

  import Claper.AccountsFixtures
  import Claper.EventsFixtures
  import Lti13.RegistrationsFixtures
  import Ecto.Query

  alias Claper.Accounts
  alias Claper.Repo
  alias Lti13.Tool.OidcLogin

  @lti "https://purl.imsglobal.org/spec/lti/claim/"
  @pending_key "lti_pending_switch"

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

    Req.Test.stub(Lti13.HTTP, fn conn -> Req.Test.json(conn, %{"keys" => [public_key]}) end)

    %{registration: registration, event: event}
  end

  describe "launch with a different logged-in user" do
    setup context do
      current = confirmed_user_fixture()
      {conn, claims} = launch(context, log_in_user(context.conn, current))
      lms_user = Accounts.get_user_by_email(claims["email"])
      %{launched: conn, current: current, lms_user: lms_user, claims: claims}
    end

    test "disabling LTI blocks a pending account switch without minting a session", ctx do
      {:ok, _} = Claper.Settings.set("lti_enabled", "false")
      pending = get_session(ctx.launched, @pending_key)

      conn =
        ctx.launched
        |> recycle()
        |> post(~p"/lti/launch/confirm", %{"token" => pending["token"]})

      assert response(conn, 404) == "Not Found"
      assert token_count(ctx.lms_user) == 0
    end

    test "asks for confirmation instead of switching sessions", ctx do
      assert redirected_to(ctx.launched) == ~p"/lti/launch/confirm"
      assert session_user(ctx.launched).id == ctx.current.id
      assert token_count(ctx.lms_user) == 0
      refute get_session(ctx.launched, :resource_id)

      page = ctx.launched |> recycle() |> get(~p"/lti/launch/confirm")
      html = html_response(page, 200)
      assert html =~ ctx.current.email
      assert html =~ ctx.lms_user.email
      assert session_user(page).id == ctx.current.id
    end

    test "confirming with a valid CSRF token logs in the LMS account", ctx do
      page = ctx.launched |> recycle() |> get(~p"/lti/launch/confirm")
      html = html_response(page, 200)

      conn =
        page
        |> recycle()
        |> enforce_csrf()
        |> post(~p"/lti/launch/confirm", %{
          "_csrf_token" => hidden(html, "_csrf_token"),
          "token" => hidden(html, "token")
        })

      assert redirected_to(conn) == ~p"/e/#{ctx.event.code}"
      assert session_user(conn).id == ctx.lms_user.id
      assert get_session(conn, @pending_key) == nil
    end

    test "confirming without a CSRF token is forbidden", ctx do
      page = ctx.launched |> recycle() |> get(~p"/lti/launch/confirm")
      html = html_response(page, 200)

      assert_error_sent 403, fn ->
        page
        |> recycle()
        |> enforce_csrf()
        |> post(~p"/lti/launch/confirm", %{"token" => hidden(html, "token")})
      end

      assert token_count(ctx.lms_user) == 0
    end

    test "a wrong pending token is rejected", ctx do
      conn = ctx.launched |> recycle() |> post(~p"/lti/launch/confirm", %{"token" => "nope"})

      assert html_response(conn, 400)
      assert session_user(conn).id == ctx.current.id
      assert token_count(ctx.lms_user) == 0
    end

    test "cancelling keeps the current account", ctx do
      conn = ctx.launched |> recycle() |> post(~p"/lti/launch/cancel")

      assert redirected_to(conn) == ~p"/events"
      assert session_user(conn).id == ctx.current.id
      assert get_session(conn, @pending_key) == nil
      assert token_count(ctx.lms_user) == 0

      replay = conn |> recycle() |> post(~p"/lti/launch/confirm", %{"token" => "any"})
      assert html_response(replay, 400)
      assert token_count(ctx.lms_user) == 0
    end
  end

  test "expired pending switch does not log in", %{conn: conn} do
    current = confirmed_user_fixture()
    target = confirmed_user_fixture()

    conn =
      conn
      |> log_in_user(current)
      |> init_test_session(%{
        @pending_key => %{
          "token" => "tok",
          "lti_user_id" => 1,
          "local_user_id" => target.id,
          "expires_at" => System.system_time(:second) - 1
        }
      })
      |> post(~p"/lti/launch/confirm", %{"token" => "tok"})

    assert html_response(conn, 400)
    assert session_user(conn).id == current.id
    assert token_count(target) == 0
  end

  test "missing pending switch does not log in", %{conn: conn} do
    current = confirmed_user_fixture()
    conn = conn |> log_in_user(current) |> post(~p"/lti/launch/confirm", %{"token" => "tok"})

    assert html_response(conn, 400)
    assert session_user(conn).id == current.id
  end

  test "revoked mapping cannot be confirmed", context do
    current = confirmed_user_fixture()
    {launched, claims} = launch(context, log_in_user(context.conn, current))
    lms_user = Accounts.get_user_by_email(claims["email"])

    Repo.update_all(
      from(u in Lti13.Users.User, where: u.user_id == ^lms_user.id),
      set: [provisioned_at: nil, authorized_at: nil]
    )

    pending = get_session(launched, @pending_key)

    conn =
      launched |> recycle() |> post(~p"/lti/launch/confirm", %{"token" => pending["token"]})

    assert html_response(conn, 400)
    assert session_user(conn).id == current.id
    assert token_count(lms_user) == 0
  end

  test "anonymous launch logs in directly", context do
    {conn, claims} = launch(context, context.conn)

    assert redirected_to(conn) == ~p"/e/#{context.event.code}"
    assert session_user(conn).email == claims["email"]
  end

  test "launch as the already logged-in user logs in directly", context do
    {first, claims} = launch(context, context.conn)
    user = session_user(first)

    {conn, _} = launch(context, log_in_user(build_conn(), user), %{"sub" => claims["sub"]})

    assert redirected_to(conn) == ~p"/e/#{context.event.code}"
    assert session_user(conn).id == user.id
    assert get_session(conn, @pending_key) == nil
  end

  defp launch(context, conn, overrides \\ %{}) do
    {state, nonce} = initiate(context.registration)
    claims = claims(context.registration, nonce, overrides)

    conn =
      conn
      |> init_test_session(%{"state" => state})
      |> enforce_csrf()
      |> post(~p"/lti/launch", %{"state" => state, "id_token" => sign(context.key, claims)})

    {conn, claims}
  end

  defp enforce_csrf(conn), do: Plug.Conn.put_private(conn, :plug_skip_csrf_protection, false)

  defp session_user(conn),
    do: Accounts.get_user_by_session_token(get_session(conn, :user_token))

  defp token_count(user) do
    Repo.aggregate(from(t in Accounts.UserToken, where: t.user_id == ^user.id), :count)
  end

  defp hidden(html, name) do
    [_, value] = Regex.run(~r/name="#{name}" value="([^"]+)"/, html)
    value
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

  defp claims(registration, nonce, overrides) do
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

  defp sign(key, claims) do
    {_, token} =
      key
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "platform-key"}, claims)
      |> JOSE.JWS.compact()

    token
  end
end
