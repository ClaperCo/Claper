defmodule ClaperWeb.LayoutViewTest do
  use ClaperWeb.ConnCase

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

  # The plug stores the locale in the test process, so each test makes a
  # single request to keep an earlier one from masking the result.
  defp get_with_language(conn, path, accept_language) do
    conn
    |> put_req_header("accept-language", accept_language)
    |> get(path)
    |> html_response(200)
  end

  describe "root layout" do
    test "sets the html lang to the locale from Accept-Language", %{conn: conn} do
      html = get_with_language(conn, ~p"/", "fr-FR,fr;q=0.9,en;q=0.8")

      assert html =~ ~s(<html lang="fr")
    end

    test "resolves a regional tag to its language", %{conn: conn} do
      assert get_with_language(conn, ~p"/", "de-AT") =~ ~s(<html lang="de")
    end

    test "falls through an untranslated regional tag to its language", %{conn: conn} do
      assert get_with_language(conn, ~p"/", "fr-CA,fr;q=0.9") =~ ~s(<html lang="fr")
    end

    test "keeps the default locale for a language without a translation", %{conn: conn} do
      assert get_with_language(conn, ~p"/", "pl") =~ ~s(<html lang="en")
    end

    test "skips untranslated languages in favour of a later one", %{conn: conn} do
      assert get_with_language(conn, ~p"/", "ja,de;q=0.5") =~ ~s(<html lang="de")
    end

    test "falls back to the default locale without Accept-Language", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")

      assert html_response(conn, 200) =~ ~s(<html lang="en")
    end
  end

  describe "admin layout" do
    setup [:register_and_log_in_admin]

    test "sets the html lang to the locale from Accept-Language", %{conn: conn} do
      assert get_with_language(conn, ~p"/admin", "de") =~ ~s(<html lang="de")
    end

    test "prefers the locale saved on the user over Accept-Language", %{conn: conn, admin: admin} do
      {:ok, _admin} = Accounts.update_user_preferences(admin, %{locale: "es"})

      assert get_with_language(conn, ~p"/admin", "de") =~ ~s(<html lang="es")
    end

    test "keeps the locale saved on the user when Accept-Language has no translation",
         %{conn: conn, admin: admin} do
      {:ok, _admin} = Accounts.update_user_preferences(admin, %{locale: "es"})

      assert get_with_language(conn, ~p"/admin", "pl") =~ ~s(<html lang="es")
    end
  end
end
