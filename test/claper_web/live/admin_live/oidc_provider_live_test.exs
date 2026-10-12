defmodule ClaperWeb.AdminLive.OidcProviderLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Claper.Accounts.Oidc
  alias ClaperWeb.UserOidcAuth

  @secret "s3cr3t-value-never-rendered"

  defp provider_fixture(attrs \\ %{}) do
    {:ok, provider} =
      attrs
      |> Enum.into(%{
        name: "Acme",
        issuer: "https://acme.example",
        client_id: "acme-client",
        client_secret: @secret,
        redirect_uri: "https://claper.example/custom/callback"
      })
      |> Oidc.create_provider()

    provider
  end

  setup [:register_and_log_in_admin]

  describe "client secret" do
    test "the stored secret is never sent to the browser", %{conn: conn} do
      provider = provider_fixture()

      {:ok, view, html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      refute html =~ @secret

      assert has_element?(
               view,
               "#provider-form input[name='provider[client_secret]'][type=password]"
             )

      refute has_element?(view, "#provider-form input[name='provider[client_secret]'][required]")
    end

    test "a blank secret keeps the stored one", %{conn: conn} do
      provider = provider_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      view
      |> form("#provider-form", %{"provider" => %{"name" => "Acme SSO", "client_secret" => ""}})
      |> render_submit()

      assert_redirect(view, ~p"/admin/oidc_providers")
      updated = Oidc.get_provider!(provider.id)
      assert updated.name == "Acme SSO"
      assert updated.client_secret == @secret
    end

    test "a typed secret replaces the stored one", %{conn: conn} do
      provider = provider_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      view
      |> form("#provider-form", %{"provider" => %{"client_secret" => "rotated"}})
      |> render_submit()

      assert_redirect(view, ~p"/admin/oidc_providers")
      assert Oidc.get_provider!(provider.id).client_secret == "rotated"
    end

    test "is required for a new provider", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/new")

      html =
        view
        |> form("#provider-form", %{
          "provider" => %{
            "name" => "Acme",
            "issuer" => "https://acme.example",
            "client_id" => "acme-client"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert Oidc.list_providers() == []
    end
  end

  describe "redirect URI" do
    test "a new provider gets the callback route of its slug", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/new")

      view
      |> form("#provider-form", %{
        "provider" => %{
          "name" => "Corp SSO",
          "issuer" => "https://corp.example",
          "client_id" => "corp-client",
          "client_secret" => @secret
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/oidc_providers")
      [provider] = Oidc.list_providers()
      assert provider.slug == "corp-sso"
      assert provider.redirect_uri == UserOidcAuth.callback_url("corp-sso")
    end

    test "follows the slug while it holds the derived value", %{conn: conn} do
      provider = provider_fixture(%{redirect_uri: UserOidcAuth.callback_url("acme")})
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      view
      |> form("#provider-form", %{"provider" => %{"slug" => "acme-sso"}})
      |> render_submit()

      assert Oidc.get_provider!(provider.id).redirect_uri ==
               UserOidcAuth.callback_url("acme-sso")
    end

    test "an edited redirect URI is kept when the slug changes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/new")

      view
      |> form("#provider-form", %{
        "provider" => %{"redirect_uri" => "https://proxy.example/callback"}
      })
      |> render_change(%{_target: ["provider", "redirect_uri"]})

      view
      |> form("#provider-form", %{
        "provider" => %{
          "name" => "Corp SSO",
          "issuer" => "https://corp.example",
          "client_id" => "corp-client",
          "client_secret" => @secret,
          "redirect_uri" => "https://proxy.example/callback"
        }
      })
      |> render_submit()

      [provider] = Oidc.list_providers()
      assert provider.redirect_uri == "https://proxy.example/callback"
    end

    test "a custom stored redirect URI is not overwritten", %{conn: conn} do
      provider = provider_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      view
      |> form("#provider-form", %{"provider" => %{"slug" => "acme-sso"}})
      |> render_submit()

      assert Oidc.get_provider!(provider.id).redirect_uri ==
               "https://claper.example/custom/callback"
    end
  end

  describe "slug" do
    test "follows the name of a new provider", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/new")

      view
      |> form("#provider-form", %{"provider" => %{"name" => "Corp SSO"}})
      |> render_change(%{_target: ["provider", "name"]})

      assert has_element?(view, "input[name='provider[slug]'][value='corp-sso']")

      assert has_element?(
               view,
               "input[name='provider[redirect_uri]'][value='#{UserOidcAuth.callback_url("corp-sso")}']"
             )
    end

    test "an edited slug no longer follows the name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/new")

      view
      |> form("#provider-form", %{"provider" => %{"slug" => "corp"}})
      |> render_change(%{_target: ["provider", "slug"]})

      view
      |> form("#provider-form", %{"provider" => %{"name" => "Corp SSO", "slug" => "corp"}})
      |> render_change(%{_target: ["provider", "name"]})

      assert has_element?(view, "input[name='provider[slug]'][value='corp']")
    end

    test "a stored slug does not follow a renamed provider", %{conn: conn} do
      provider = provider_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/oidc_providers/#{provider}/edit")

      view
      |> form("#provider-form", %{"provider" => %{"name" => "Acme Workspace"}})
      |> render_submit()

      assert Oidc.get_provider!(provider.id).slug == "acme"
    end
  end
end
