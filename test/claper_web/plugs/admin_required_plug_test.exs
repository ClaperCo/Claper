defmodule ClaperWeb.AdminRequiredPlugTest do
  use ClaperWeb.ConnCase

  alias ClaperWeb.Plugs.AdminRequiredPlug
  alias Claper.Accounts
  alias Claper.Accounts.User

  @valid_user_attrs %{email: "user@example.com", password: "Password123!"}
  @valid_admin_attrs %{email: "admin@example.com", password: "Password123!"}

  setup do
    # Create roles
    {:ok, _user_role} = Accounts.create_role(%{name: "user"})
    {:ok, admin_role} = Accounts.create_role(%{name: "admin"})

    # Create a regular user
    {:ok, user} = Accounts.create_user(@valid_user_attrs)

    # Create an admin user
    {:ok, admin} = Accounts.create_user(@valid_admin_attrs)
    {:ok, admin} = Accounts.assign_role(admin, admin_role)

    %{user: user, admin: admin}
  end

  describe "init/1" do
    test "returns options unchanged" do
      assert AdminRequiredPlug.init([]) == []
    end
  end

  describe "call/2" do
    test "allows access to admin users", %{conn: conn, admin: admin} do
      # Log in as admin
      conn =
        conn
        |> sign_in_user(admin)
        |> AdminRequiredPlug.call([])

      # Should pass through without redirect
      refute conn.halted
    end

    test "redirects non-admin users", %{conn: conn, user: user} do
      # Log in as regular user
      conn =
        conn
        |> sign_in_user(user)
        |> AdminRequiredPlug.call([])

      # Should be halted and redirected
      assert conn.halted
      assert redirected_to(conn) =~ "/"
      assert get_flash(conn, :error) =~ "You must be an administrator"
    end

    test "redirects unauthenticated users", %{conn: conn} do
      conn = AdminRequiredPlug.call(conn, [])

      # Should be halted and redirected
      assert conn.halted
      assert redirected_to(conn) =~ "/users/log_in"
    end
  end

  defp sign_in_user(conn, user) do
    conn
    |> Map.replace!(:secret_key_base, ClaperWeb.Endpoint.config(:secret_key_base))
    |> init_test_session(%{})
    |> Accounts.Guardian.Plug.sign_in(user)
  end
end
