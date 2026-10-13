defmodule ClaperWeb.AdminLive.DashboardLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Claper.EventsFixtures

  alias Claper.Accounts

  defp role_fixture(name) do
    Accounts.get_role_by_name(name) ||
      case Accounts.create_role(%{name: name}) do
        {:ok, role} -> role
        {:error, _changeset} -> Accounts.get_role_by_name(name)
      end
  end

  defp register_and_log_in_admin(%{conn: conn}) do
    role_fixture("user")
    role_fixture("admin")

    user = confirmed_user_fixture()
    {:ok, user} = Accounts.assign_role(user, "admin")

    %{conn: log_in_user(conn, user), admin: user}
  end

  describe "dashboard" do
    setup [:register_and_log_in_admin]

    test "shows recent event start dates without English month names", %{conn: conn} do
      event_fixture(%{name: "Dashboard Event", started_at: ~N[2099-03-05 10:00:00]})

      {:ok, _view, html} = live(conn, ~p"/admin")

      assert html =~ "Dashboard Event"
      assert html =~ "2099-03-05"
      refute html =~ "Mar 05"
    end
  end

  describe "access" do
    setup [:register_and_log_in_user]

    test "turns away non-admins with a notice in their language", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept-language", "de")
        |> get(~p"/admin")

      assert redirected_to(conn) == ~p"/events"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Sie müssen Administrator sein, um auf diese Seite zuzugreifen."
    end
  end
end
