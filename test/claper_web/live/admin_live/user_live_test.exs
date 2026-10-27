defmodule ClaperWeb.AdminLive.UserLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Claper.EventsFixtures

  alias Claper.Accounts
  alias Claper.Repo

  defp role_fixture(name) do
    Accounts.get_role_by_name(name) ||
      case Accounts.create_role(%{name: name}) do
        {:ok, role} -> role
        {:error, _changeset} -> Accounts.get_role_by_name(name)
      end
  end

  setup %{conn: conn} do
    role_fixture("user")
    role_fixture("admin")

    admin = confirmed_user_fixture()
    {:ok, admin} = Accounts.assign_role(admin, "admin")

    %{conn: log_in_user(conn, admin)}
  end

  test "users and events lists have no row actions", %{conn: conn} do
    user = confirmed_user_fixture()
    event_fixture(%{user: user})

    {:ok, users_view, _html} = live(conn, ~p"/admin/users")
    refute has_element?(users_view, "[phx-click]")

    {:ok, events_view, _html} = live(conn, ~p"/admin/events")
    refute has_element?(events_view, "[phx-click]")
  end

  test "enabling a disabled user restores the account", %{conn: conn} do
    user = confirmed_user_fixture()
    {:ok, user} = Accounts.delete_user(user)
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user}")

    html = view |> element("button[phx-click=enable]") |> render_click()

    assert html =~ "User enabled successfully"
    refute Accounts.deleted?(Accounts.get_user!(user.id))
    assert has_element?(view, "button[phx-click=disable]")
  end

  test "disabling from the user details page keeps the account and its events", %{conn: conn} do
    user = confirmed_user_fixture()
    event = event_fixture(%{user: user})
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user}")

    view |> element("button[phx-click=disable]") |> render_click()

    assert_patch(view, ~p"/admin/users/#{user}")
    assert render(view) =~ "User disabled successfully"
    assert Accounts.deleted?(Accounts.get_user!(user.id))
    assert Repo.get(Claper.Events.Event, event.id)
    refute has_element?(view, "button[phx-click=disable]")
    assert has_element?(view, "button[phx-click=enable]")
  end

  test "deleting from the user details page removes the account and its events", %{conn: conn} do
    user = confirmed_user_fixture()
    event = event_fixture(%{user: user})
    {:ok, view, _html} = live(conn, ~p"/admin/users/#{user}")

    view |> element("button[phx-click=delete]") |> render_click()

    assert_patch(view, ~p"/admin/users")
    refute Repo.get(Accounts.User, user.id)
    refute Repo.get(Claper.Events.Event, event.id)
  end

  test "deleting from the event details page returns to the events list", %{conn: conn} do
    event = event_fixture()
    {:ok, view, _html} = live(conn, ~p"/admin/events/#{event}")

    view |> element("button[phx-click=delete]") |> render_click()

    assert_patch(view, ~p"/admin/events")
    refute Repo.get(Claper.Events.Event, event.id)
  end
end
