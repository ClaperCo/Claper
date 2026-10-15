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

    test "localizes the response mode label without translating protocol option names", %{
      conn: conn
    } do
      {:ok, view, html} =
        conn
        |> put_req_header("accept-language", "de")
        |> live(~p"/admin/oidc_providers/new")

      {:ok, _english_view, english_html} =
        conn
        |> put_req_header("accept-language", "en")
        |> live(~p"/admin/oidc_providers/new")

      refute response_mode_label(html) == response_mode_label(english_html)

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

  defp response_mode_label(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".form-control")
    |> Enum.find(&(Floki.find(&1, "select[name='provider[response_mode]']") != []))
    |> Floki.find("label")
    |> Floki.text()
  end
end
