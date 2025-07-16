defmodule ClaperWeb.Admin.UserControllerTest do
  use ClaperWeb.ConnCase

  alias Claper.Accounts
  alias Claper.Accounts.User
  alias Claper.Repo

  @valid_user_attrs %{email: "test@example.com", password: "Password123!"}
  @update_attrs %{email: "updated@example.com"}
  @invalid_attrs %{email: "not-an-email", password: "short"}

  setup do
    # Create roles
    {:ok, user_role} = Accounts.create_role(%{name: "user"})
    {:ok, admin_role} = Accounts.create_role(%{name: "admin"})
    
    # Create an admin user
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "Password123!"})
    {:ok, admin} = Accounts.assign_role(admin, admin_role)
    
    # Create a regular user for testing
    {:ok, user} = Accounts.create_user(@valid_user_attrs)
    {:ok, user} = Accounts.assign_role(user, user_role)
    
    # Create a conn with admin logged in
    admin_conn = 
      build_conn()
      |> Map.replace!(:secret_key_base, ClaperWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Accounts.Guardian.Plug.sign_in(admin)
    
    %{admin: admin, user: user, admin_conn: admin_conn}
  end

  describe "index" do
    test "lists all users", %{admin_conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index))
      assert html_response(conn, 200) =~ "Users Management"
      assert html_response(conn, 200) =~ "admin@example.com"
      assert html_response(conn, 200) =~ "test@example.com"
    end

    test "exports users as CSV", %{admin_conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index, format: "csv"))
      
      assert response_content_type(conn, :csv)
      assert response(conn, 200) =~ "Email,Name,Role,Created At"
      assert response(conn, 200) =~ "admin@example.com"
      assert response(conn, 200) =~ "test@example.com"
    end
  end

  describe "new user" do
    test "renders form", %{admin_conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :new))
      assert html_response(conn, 200) =~ "New User"
    end
  end

  describe "create user" do
    test "redirects to show when data is valid", %{admin_conn: conn} do
      conn = post(conn, Routes.admin_user_path(conn, :create), user: %{email: "new@example.com", password: "Password123!"})

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_user_path(conn, :show, id)

      conn = get(conn, Routes.admin_user_path(conn, :show, id))
      assert html_response(conn, 200) =~ "new@example.com"
    end

    test "renders errors when data is invalid", %{admin_conn: conn} do
      conn = post(conn, Routes.admin_user_path(conn, :create), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "New User"
      assert html_response(conn, 200) =~ "is invalid"
    end
  end

  describe "edit user" do
    test "renders form for editing chosen user", %{admin_conn: conn, user: user} do
      conn = get(conn, Routes.admin_user_path(conn, :edit, user))
      assert html_response(conn, 200) =~ "Edit User"
    end
  end

  describe "update user" do
    test "redirects when data is valid", %{admin_conn: conn, user: user} do
      conn = put(conn, Routes.admin_user_path(conn, :update, user), user: @update_attrs)
      assert redirected_to(conn) == Routes.admin_user_path(conn, :show, user)

      conn = get(conn, Routes.admin_user_path(conn, :show, user))
      assert html_response(conn, 200) =~ "updated@example.com"
    end

    test "renders errors when data is invalid", %{admin_conn: conn, user: user} do
      conn = put(conn, Routes.admin_user_path(conn, :update, user), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit User"
    end
  end

  describe "delete user" do
    test "deletes chosen user", %{admin_conn: conn, user: user} do
      conn = delete(conn, Routes.admin_user_path(conn, :delete, user))
      assert redirected_to(conn) == Routes.admin_user_path(conn, :index)
      
      # Verify user is deleted (or soft-deleted depending on implementation)
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!(user.id)
      end
    end
  end

  describe "promote user" do
    test "promotes user to admin", %{admin_conn: conn, user: user} do
      conn = post(conn, Routes.admin_user_path(conn, :promote, user))
      assert redirected_to(conn) == Routes.admin_user_path(conn, :index)
      
      # Verify user is now admin
      updated_user = Repo.get(User, user.id) |> Repo.preload(:role)
      assert updated_user.role.name == "admin"
    end
  end

  describe "demote user" do
    test "demotes admin to regular user", %{admin_conn: conn, admin: admin, user: user} do
      # First promote the test user to admin
      {:ok, user} = Accounts.promote_to_admin(user)
      
      # Then demote
      conn = post(conn, Routes.admin_user_path(conn, :demote, user))
      assert redirected_to(conn) == Routes.admin_user_path(conn, :index)
      
      # Verify user is now a regular user
      updated_user = Repo.get(User, user.id) |> Repo.preload(:role)
      assert updated_user.role.name == "user"
      
      # Cannot demote the last admin
      conn = post(conn, Routes.admin_user_path(conn, :demote, admin))
      assert get_flash(conn, :error) =~ "Cannot demote the last admin"
      
      # Verify admin is still admin
      updated_admin = Repo.get(User, admin.id) |> Repo.preload(:role)
      assert updated_admin.role.name == "admin"
    end
  end
end
