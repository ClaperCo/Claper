defmodule ClaperWeb.Router.AdminRoutesTest do
  use ClaperWeb.ConnCase

  alias Claper.Accounts
  alias Claper.Accounts.User

  @admin_routes [
    "/admin",
    "/admin/users",
    "/admin/events",
    "/admin/oidc_providers"
  ]

  setup do
    # Create roles
    {:ok, user_role} = Accounts.create_role(%{name: "user"})
    {:ok, admin_role} = Accounts.create_role(%{name: "admin"})

    # Create a regular user
    {:ok, user} = Accounts.create_user(%{email: "user@example.com", password: "Password123!"})
    {:ok, user} = Accounts.assign_role(user, user_role)

    # Create an admin user
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "Password123!"})
    {:ok, admin} = Accounts.assign_role(admin, admin_role)

    %{user: user, admin: admin}
  end

  describe "admin routes access restrictions" do
    test "admin user can access all admin routes", %{conn: conn, admin: admin} do
      # Log in as admin
      conn =
        conn
        |> sign_in_user(admin)

      # Test each admin route
      for route <- @admin_routes do
        conn = get(conn, route)

        assert conn.status in [200, 302],
               "Admin should be able to access #{route}, got status #{conn.status}"

        refute get_flash(conn, :error) =~ "You must be an administrator"
      end
    end

    test "regular user cannot access admin routes", %{conn: conn, user: user} do
      # Log in as regular user
      conn =
        conn
        |> sign_in_user(user)

      # Test each admin route
      for route <- @admin_routes do
        conn = get(conn, route)
        assert conn.status == 302, "Regular user should be redirected from #{route}"
        assert get_flash(conn, :error) =~ "You must be an administrator"
        assert redirected_to(conn) == "/"
      end
    end

    test "unauthenticated user cannot access admin routes", %{conn: conn} do
      # Test each admin route
      for route <- @admin_routes do
        conn = get(conn, route)
        assert conn.status == 302, "Unauthenticated user should be redirected from #{route}"
        assert redirected_to(conn) =~ "/users/log_in"
      end
    end
  end

  defp sign_in_user(conn, user) do
    conn
    |> Map.replace!(:secret_key_base, ClaperWeb.Endpoint.config(:secret_key_base))
    |> init_test_session(%{})
    |> Accounts.Guardian.Plug.sign_in(user)
  end
end
