defmodule ClaperWeb.Admin.OidcProviderControllerTest do
  use ClaperWeb.ConnCase

  alias Claper.Accounts
  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider

  @valid_provider_attrs %{
    name: "Test Provider",
    issuer: "https://example.com",
    client_id: "test_client_id",
    client_secret: "test_client_secret",
    redirect_uri: "https://app.example.com/callback",
    scope: "openid email profile",
    active: true
  }
  @update_attrs %{
    name: "Updated Provider",
    client_id: "updated_client_id",
    client_secret: "updated_client_secret"
  }
  @invalid_attrs %{name: nil, issuer: nil, client_id: nil, client_secret: nil, redirect_uri: nil}

  setup do
    # Create roles
    {:ok, user_role} = Accounts.create_role(%{name: "user"})
    {:ok, admin_role} = Accounts.create_role(%{name: "admin"})

    # Create an admin user
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "Password123!"})
    {:ok, admin} = Accounts.assign_role(admin, admin_role)

    # Create a test OIDC provider
    {:ok, provider} = Oidc.create_provider(@valid_provider_attrs)

    # Create a conn with admin logged in
    admin_conn =
      build_conn()
      |> Map.replace!(:secret_key_base, ClaperWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Accounts.Guardian.Plug.sign_in(admin)

    %{admin: admin, provider: provider, admin_conn: admin_conn}
  end

  describe "index" do
    test "lists all OIDC providers", %{admin_conn: conn, provider: provider} do
      conn = get(conn, Routes.admin_oidc_provider_path(conn, :index))
      assert html_response(conn, 200) =~ "OIDC Providers List"
      assert html_response(conn, 200) =~ provider.name
    end

    test "exports providers as CSV", %{admin_conn: conn, provider: provider} do
      conn = get(conn, Routes.admin_oidc_provider_path(conn, :index, format: "csv"))

      assert response_content_type(conn, :csv)
      assert response(conn, 200) =~ "Name,Issuer,Client ID,Active"
      assert response(conn, 200) =~ provider.name
      assert response(conn, 200) =~ provider.issuer
      # Client secret should not be included in CSV export for security
      refute response(conn, 200) =~ provider.client_secret
    end
  end

  describe "new provider" do
    test "renders form", %{admin_conn: conn} do
      conn = get(conn, Routes.admin_oidc_provider_path(conn, :new))
      assert html_response(conn, 200) =~ "Add New OIDC Provider"
    end
  end

  describe "create provider" do
    test "redirects to show when data is valid", %{admin_conn: conn} do
      new_provider_attrs = Map.put(@valid_provider_attrs, :name, "New Test Provider")

      conn =
        post(conn, Routes.admin_oidc_provider_path(conn, :create), provider: new_provider_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_oidc_provider_path(conn, :show, id)

      conn = get(conn, Routes.admin_oidc_provider_path(conn, :show, id))
      assert html_response(conn, 200) =~ "New Test Provider"
    end

    test "renders errors when data is invalid", %{admin_conn: conn} do
      conn = post(conn, Routes.admin_oidc_provider_path(conn, :create), provider: @invalid_attrs)
      assert html_response(conn, 200) =~ "Add New OIDC Provider"
      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "validates provider data before creating", %{admin_conn: conn} do
      invalid_url_attrs =
        Map.merge(@valid_provider_attrs, %{
          name: "Invalid URL Provider",
          # Not a valid URL
          issuer: "invalid-url",
          redirect_uri: "also-invalid"
        })

      conn =
        post(conn, Routes.admin_oidc_provider_path(conn, :create), provider: invalid_url_attrs)

      assert html_response(conn, 200) =~ "Add New OIDC Provider"
      assert html_response(conn, 200) =~ "must start with http"
    end
  end

  describe "edit provider" do
    test "renders form for editing chosen provider", %{admin_conn: conn, provider: provider} do
      conn = get(conn, Routes.admin_oidc_provider_path(conn, :edit, provider))
      assert html_response(conn, 200) =~ "Edit OIDC Provider"
      assert html_response(conn, 200) =~ provider.name
    end
  end

  describe "update provider" do
    test "redirects when data is valid", %{admin_conn: conn, provider: provider} do
      conn =
        put(conn, Routes.admin_oidc_provider_path(conn, :update, provider),
          provider: @update_attrs
        )

      assert redirected_to(conn) == Routes.admin_oidc_provider_path(conn, :show, provider)

      conn = get(conn, Routes.admin_oidc_provider_path(conn, :show, provider))
      assert html_response(conn, 200) =~ "Updated Provider"
    end

    test "renders errors when data is invalid", %{admin_conn: conn, provider: provider} do
      conn =
        put(conn, Routes.admin_oidc_provider_path(conn, :update, provider),
          provider: @invalid_attrs
        )

      assert html_response(conn, 200) =~ "Edit OIDC Provider"
      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "validates provider data before updating", %{admin_conn: conn, provider: provider} do
      invalid_url_attrs = %{
        # Not a valid URL
        issuer: "invalid-url",
        redirect_uri: "also-invalid"
      }

      conn =
        put(conn, Routes.admin_oidc_provider_path(conn, :update, provider),
          provider: invalid_url_attrs
        )

      assert html_response(conn, 200) =~ "Edit OIDC Provider"
      assert html_response(conn, 200) =~ "must start with http"
    end
  end

  describe "delete provider" do
    test "deletes chosen provider", %{admin_conn: conn, provider: provider} do
      conn = delete(conn, Routes.admin_oidc_provider_path(conn, :delete, provider))
      assert redirected_to(conn) == Routes.admin_oidc_provider_path(conn, :index)

      assert_raise Ecto.NoResultsError, fn ->
        Oidc.get_provider!(provider.id)
      end
    end
  end
end
