defmodule Claper.Accounts.RoleTest do
  use Claper.DataCase

  alias Claper.Accounts
  alias Claper.Accounts.{User, Role}
  alias Claper.Repo

  describe "roles" do
    setup do
      # Ensure admin and user roles exist
      {:ok, _admin_role} = Accounts.create_role(%{name: "admin"})
      {:ok, _user_role} = Accounts.create_role(%{name: "user"})
      :ok
    end

    test "list_roles/0 returns all roles" do
      roles = Accounts.list_roles()
      assert length(roles) == 2
      assert Enum.any?(roles, fn r -> r.name == "admin" end)
      assert Enum.any?(roles, fn r -> r.name == "user" end)
    end

    test "get_role!/1 returns the role with given id" do
      role = Repo.get_by(Role, name: "admin")
      assert Accounts.get_role!(role.id).name == "admin"
    end

    test "get_role_by_name/1 returns the role with given name" do
      assert Accounts.get_role_by_name("admin").name == "admin"
      assert Accounts.get_role_by_name("user").name == "user"
      assert Accounts.get_role_by_name("nonexistent") == nil
    end

    test "create_role/1 with valid data creates a role" do
      assert {:ok, %Role{} = role} = Accounts.create_role(%{name: "moderator"})
      assert role.name == "moderator"
    end

    test "create_role/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_role(%{name: nil})
    end
  end

  describe "user role management" do
    setup do
      # Ensure admin and user roles exist
      {:ok, admin_role} = Accounts.create_role(%{name: "admin"})
      {:ok, user_role} = Accounts.create_role(%{name: "user"})

      # Create a test user
      {:ok, user} = Accounts.create_user(%{email: "test@example.com", password: "Password123!"})

      %{user: user, admin_role: admin_role, user_role: user_role}
    end

    test "assign_role/2 assigns a role to a user", %{user: user, admin_role: admin_role} do
      assert {:ok, updated_user} = Accounts.assign_role(user, admin_role)
      assert updated_user.role_id == admin_role.id

      # Verify through a fresh database query
      fresh_user = Repo.get(User, user.id) |> Repo.preload(:role)
      assert fresh_user.role.name == "admin"
    end

    test "get_user_role/1 returns the role of a user", %{user: user, user_role: user_role} do
      # Assign a role first
      {:ok, user} = Accounts.assign_role(user, user_role)

      # Test getting the role
      role = Accounts.get_user_role(user)
      assert role.id == user_role.id
      assert role.name == "user"
    end

    test "list_users_by_role/1 returns users with a specific role", %{
      user: user,
      admin_role: admin_role
    } do
      # Create another user with a different role
      {:ok, user2} =
        Accounts.create_user(%{email: "another@example.com", password: "Password123!"})

      {:ok, _} = Accounts.assign_role(user, admin_role)

      # Get users with admin role
      admin_users = Accounts.list_users_by_role("admin")
      assert length(admin_users) == 1
      assert hd(admin_users).id == user.id

      # Verify user2 is not in the list
      assert user2.id not in Enum.map(admin_users, & &1.id)
    end

    test "user_has_role?/2 checks if a user has a specific role", %{
      user: user,
      admin_role: admin_role
    } do
      # Initially user has no role
      refute Accounts.user_has_role?(user, "admin")

      # Assign admin role
      {:ok, user} = Accounts.assign_role(user, admin_role)

      # Now user should have admin role
      assert Accounts.user_has_role?(user, "admin")
      refute Accounts.user_has_role?(user, "user")
    end

    test "promote_to_admin/1 promotes a user to admin", %{user: user} do
      # Initially user should not be admin
      refute Accounts.user_has_role?(user, "admin")

      # Promote to admin
      {:ok, user} = Accounts.promote_to_admin(user)

      # Verify promotion
      assert Accounts.user_has_role?(user, "admin")
    end

    test "demote_from_admin/1 demotes a user from admin", %{user: user} do
      # First promote to admin
      {:ok, user} = Accounts.promote_to_admin(user)
      assert Accounts.user_has_role?(user, "admin")

      # Then demote
      {:ok, user} = Accounts.demote_from_admin(user)

      # Verify demotion
      refute Accounts.user_has_role?(user, "admin")
      assert Accounts.user_has_role?(user, "user")
    end
  end
end
