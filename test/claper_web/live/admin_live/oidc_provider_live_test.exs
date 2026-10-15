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

    test "keeps OIDC technical labels and protocol options unchanged across locales", %{
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

      for {field, label} <- [
            {"issuer", "Issuer URL"},
            {"client_id", "Client ID"},
            {"client_secret", "Client Secret"},
            {"redirect_uri", "Redirect URI"},
            {"scope", "Scope"},
            {"response_type", "Response Type"},
            {"response_mode", "Response Mode"}
          ] do
        assert field_label(html, field) == label
        assert field_label(english_html, field) == label
      end

      refute field_label(html, "active") == field_label(english_html, "active")

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

  defp field_label(html, field) do
    html
    |> Floki.parse_document!()
    |> Floki.find(".form-control")
    |> Enum.find(&(Floki.find(&1, "[name='provider[#{field}]']") != []))
    |> Floki.find("label > .label-text")
    |> Floki.text()
  end
end
