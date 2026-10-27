defmodule ClaperWeb.UserSettingsLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Lti13.RegistrationsFixtures

  alias Claper.Accounts

  setup :register_and_log_in_user

  test "shows the user's names", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    assert has_element?(view, "p", user.first_name)
    assert has_element?(view, "p", user.last_name)
    assert has_element?(view, "a[href='/users/settings/edit/profile']", "Change")
  end

  test "updates the user's profile", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    view
    |> form("#update_profile", %{
      "user" => %{"first_name" => "Jane", "last_name" => "Smith"}
    })
    |> render_submit()

    assert_redirect(view, ~p"/users/settings")

    updated_user = Accounts.get_user!(user.id)
    assert updated_user.first_name == "Jane"
    assert updated_user.last_name == "Smith"
  end

  test "requires both names", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    html =
      view
      |> form("#update_profile", %{
        "user" => %{"first_name" => "", "last_name" => "Smith"}
      })
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#update_profile")
  end

  test "legacy LMS recovery requires an explicit password-authenticated approval", %{
    conn: conn,
    user: user
  } do
    registration = registration_fixture()

    {:ok, mapping} =
      Lti13.Users.create_user(%{
        sub: "recognized-platform-user",
        name: "Local User",
        email: user.email,
        roles: ["Learner"],
        user_id: user.id,
        registration_id: registration.id
      })

    {:ok, view, html} = live(conn, ~p"/users/settings")
    assert html =~ registration.issuer
    assert html =~ mapping.sub
    assert has_element?(view, "#approve-lti-#{mapping.id}")
    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at == nil

    view
    |> form("#approve-lti-#{mapping.id}", %{"password" => "wrong password"})
    |> render_submit()

    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at == nil

    view
    |> form("#approve-lti-#{mapping.id}", %{"password" => valid_user_password()})
    |> render_submit()

    assert_redirect(view, ~p"/users/settings")
    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at
  end

  test "forged approval events cannot authorize another user's LMS identity", %{conn: conn} do
    other_user = confirmed_user_fixture()
    registration = registration_fixture()

    {:ok, mapping} =
      Lti13.Users.create_user(%{
        sub: "someone-elses-platform-user",
        name: "Other User",
        email: other_user.email,
        roles: ["Learner"],
        user_id: other_user.id,
        registration_id: registration.id
      })

    {:ok, view, html} = live(conn, ~p"/users/settings")
    refute html =~ mapping.sub

    render_submit(view, "approve_lti_identity", %{
      "mapping_id" => to_string(mapping.id),
      "password" => valid_user_password()
    })

    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at == nil
  end

  test "legacy LMS identities on pending platforms cannot be approved", %{conn: conn, user: user} do
    registration = registration_fixture(%{approved: false})

    {:ok, mapping} =
      Lti13.Users.create_user(%{
        sub: "pending-platform-user",
        name: "Local User",
        email: user.email,
        roles: ["Learner"],
        user_id: user.id,
        registration_id: registration.id
      })

    {:ok, view, html} = live(conn, ~p"/users/settings")
    assert html =~ registration.client_id
    assert html =~ "Pending administrator approval"
    refute has_element?(view, "#approve-lti-#{mapping.id}")
    assert has_element?(view, "#lti-pending-#{mapping.id}")

    render_submit(view, "approve_lti_identity", %{
      "mapping_id" => to_string(mapping.id),
      "password" => valid_user_password()
    })

    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at == nil
  end

  test "approval events without a password do not crash", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    assert render_submit(view, "approve_lti_identity", %{"mapping_id" => "1"}) =~
             "Unable to approve LMS sign-in"

    assert render_submit(view, "approve_lti_identity", %{}) =~ "Unable to approve LMS sign-in"
  end

  test "approval attempts are rate limited", %{conn: conn, user: user} do
    registration = registration_fixture()

    {:ok, mapping} =
      Lti13.Users.create_user(%{
        sub: "rate-limited-platform-user",
        name: "Local User",
        email: user.email,
        roles: ["Learner"],
        user_id: user.id,
        registration_id: registration.id
      })

    {:ok, view, _html} = live(conn, ~p"/users/settings")

    for _ <- 1..5 do
      view
      |> form("#approve-lti-#{mapping.id}", %{"password" => "wrong password"})
      |> render_submit()
    end

    html =
      view
      |> form("#approve-lti-#{mapping.id}", %{"password" => valid_user_password()})
      |> render_submit()

    assert html =~ "Too many approval attempts"
    assert Claper.Repo.get!(Lti13.Users.User, mapping.id).authorized_at == nil
  end
end
