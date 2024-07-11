defmodule Lti13.UsersTest do
  use Claper.DataCase

  alias Lti13.Users
  alias Lti13.Users.User

  import Lti13.RegistrationsFixtures
  import Claper.AccountsFixtures

  # :sub, :name, :email, :roles, :user_id, :registration_id
  describe "users" do
    setup do
      claper_user = user_fixture()
      registration = registration_fixture()
      %{registration: registration, claper_user: claper_user}
    end

    test "create_user/1 creates a new user", %{
      registration: registration,
      claper_user: claper_user
    } do
      attrs = %{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        email: "john@example.com",
        roles: ["role1", "role2"],
        user_id: claper_user.id,
        registration_id: registration.id
      }

      assert {:ok, %User{} = user} = Users.create_user(attrs)
      assert user.id
      assert user.sub == attrs.sub
      assert user.name == attrs.name
      assert user.email == attrs.email
      assert user.roles == attrs.roles
      assert user.user_id == claper_user.id
      assert user.registration_id == registration.id
    end

    test "get_user_by_sub/1 returns the user with matching sub", %{
      registration: registration,
      claper_user: claper_user
    } do
      attrs = %{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        email: "john@example.com",
        roles: ["role1", "role2"],
        user_id: claper_user.id,
        registration_id: registration.id
      }

      {:ok, %User{} = user} = Users.create_user(attrs)

      assert %User{id: id} = Users.get_user_by_sub(attrs.sub)
      assert id == user.id
    end

    test "get_or_create_user/1 creates a new user if not found", %{
      registration: registration,
      claper_user: claper_user
    } do
      attrs = %{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        roles: ["role1", "role2"],
        email: claper_user.email,
        client_id: registration.client_id,
        issuer: registration.issuer
      }

      assert {:ok, %User{} = user} = Users.get_or_create_user(attrs)
      assert user.id
      assert user.sub == attrs.sub
      assert user.name
      assert user.email == attrs.email
      assert user.roles == attrs.roles
      assert user.user_id == claper_user.id
      assert user.registration_id == registration.id
    end

    test "get_or_create_user/1 returns existing user if found", %{
      registration: registration,
      claper_user: claper_user
    } do
      attrs = %{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        roles: ["role1", "role2"],
        email: claper_user.email,
        client_id: registration.client_id,
        issuer: registration.issuer,
        registration_id: registration.id,
        user_id: claper_user.id
      }

      {:ok, %User{} = user} = Users.create_user(attrs)

      assert {:ok, %User{} = found_user} = Users.get_or_create_user(attrs)
      assert found_user.id == user.id
    end
  end
end
