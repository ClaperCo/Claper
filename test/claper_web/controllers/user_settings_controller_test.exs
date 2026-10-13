defmodule ClaperWeb.UserSettingsControllerTest do
  use ClaperWeb.ConnCase, async: true

  alias Claper.Accounts
  import Claper.AccountsFixtures

  setup :register_and_log_in_user

  describe "GET /users/settings/confirm_email/:token" do
    test "confirms the new email in the user's language", %{conn: conn, user: user} do
      email = unique_user_email()

      {:ok, token} =
        Accounts.deliver_update_email_instructions(
          %{user | email: email},
          user.email,
          &"/users/settings/confirm_email/#{&1}"
        )

      conn =
        conn
        |> put_req_header("accept-language", "de")
        |> get(~p"/users/settings/confirm_email/#{token}")

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "E-Mail-Adresse erfolgreich geändert."

      assert Accounts.get_user_by_email(email)
    end

    test "rejects an invalid link in the user's language", %{conn: conn, user: user} do
      conn =
        conn
        |> put_req_header("accept-language", "de")
        |> get(~p"/users/settings/confirm_email/#{"oops"}")

      assert redirected_to(conn) == ~p"/users/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Der Link zur Änderung der E-Mail-Adresse ist ungültig oder abgelaufen."

      assert Accounts.get_user_by_email(user.email)
    end
  end
end
