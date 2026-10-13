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

    test "keeps protocol option names untranslated and translates the response mode label", %{
      conn: conn
    } do
      {:ok, view, html} =
        conn
        |> put_req_header("accept-language", "de")
        |> live(~p"/admin/oidc_providers/new")

      assert html =~ "Antwortmodus"

      assert has_element?(
               view,
               "select[name='provider[response_type]'] option[value='code']",
               "Authorization Code"
             )

      assert has_element?(
               view,
               "select[name='provider[response_type]'] option[value='token']",
               "Implicit"
             )

      assert has_element?(
               view,
               "select[name='provider[response_type]'] option[value='code token']",
               "Hybrid"
             )

      assert has_element?(
               view,
               "select[name='provider[response_mode]'] option[value='query']",
               "Query"
             )

      assert has_element?(
               view,
               "select[name='provider[response_mode]'] option[value='fragment']",
               "Fragment"
             )

      assert has_element?(
               view,
               "select[name='provider[response_mode]'] option[value='form_post']",
               "Form Post"
             )
    end
  end
end
