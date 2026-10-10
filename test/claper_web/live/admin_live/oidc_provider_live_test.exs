defmodule ClaperWeb.AdminLive.OidcProviderLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures

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

  describe "form" do
    setup [:register_and_log_in_admin]

    test "translates the response type and mode options", %{conn: conn} do
      {:ok, _view, html} =
        conn
        |> put_req_header("accept-language", "de")
        |> live(~p"/admin/oidc_providers/new")

      assert html =~ "Autorisierungscode"
      assert html =~ "Antwortmodus"
      assert html =~ "Formular-POST"
    end
  end
end
