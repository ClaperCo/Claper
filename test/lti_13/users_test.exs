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

      assert %User{id: id} =
               Users.get_user_by_sub_and_registration_id(attrs.sub, attrs.registration_id)

      assert id == user.id
    end

    test "get_or_create_user/1 creates a new user if not found", %{
      registration: registration
    } do
      attrs = %{
        sub: "a6d5c443-1f51-4783-ba1a-7686ffe3b54a",
        name: "John Doe",
        first_name: "John",
        last_name: "Doe",
        roles: ["role1", "role2"],
        email: unique_user_email(),
        registration_id: registration.id
      }

      assert {:ok, %User{} = user} = Users.get_or_create_user(attrs)
      assert user.id
      assert user.sub == attrs.sub
      assert user.name
      assert user.email == attrs.email
      assert user.roles == attrs.roles
      assert user.registration_id == registration.id
      assert user.user.first_name == "John"
      assert user.user.last_name == "Doe"
    end

    test "rejects existing local emails, including administrators", %{registration: registration} do
      admin_role =
        Claper.Accounts.get_role_by_name("admin") ||
          elem(Claper.Accounts.create_role(%{name: "admin", permissions: %{}}), 1)

      for user <- [user_fixture(), user_fixture(%{role_id: admin_role.id})] do
        attrs = launch_attrs(registration, %{email: user.email})

        assert {:error, %{reason: :invalid_user}} = Users.get_or_create_user(attrs)
        assert Users.get_user_by_sub_and_registration_id(attrs.sub, registration.id) == nil
        assert Claper.Accounts.get_user!(user.id).first_name == user.first_name
      end
    end

    test "rejects legacy poisoned mappings without trusting claimed provenance", %{
      registration: registration,
      claper_user: claper_user
    } do
      attrs =
        launch_attrs(registration, %{
          email: claper_user.email,
          user_id: claper_user.id,
          provisioned_at: NaiveDateTime.utc_now(),
          authorized_at: NaiveDateTime.utc_now()
        })

      assert {:ok, legacy} = Users.create_user(attrs)
      assert legacy.provisioned_at == nil
      assert {:error, %{reason: :invalid_user}} = Users.get_or_create_user(attrs)
      assert legacy.authorized_at == nil

      assert {:error, %{reason: :invalid_user}} =
               Users.authorize_legacy_user(claper_user, legacy.id, "wrong password")

      assert {:ok} = Users.authorize_legacy_user(claper_user, legacy.id, valid_user_password())
      assert {:ok, approved} = Users.get_or_create_user(attrs)
      assert approved.authorized_at
      assert approved.provisioned_at == nil
      assert approved.user_id == claper_user.id
    end

    test "new bindings survive repeat launches without changing local names or role", %{
      registration: registration
    } do
      attrs = launch_attrs(registration)
      assert {:ok, user} = Users.get_or_create_user(attrs)
      assert user.provisioned_at
      victim = user_fixture()

      assert {:ok, local} =
               Claper.Accounts.update_user_profile(user.user, %{
                 first_name: "Local",
                 last_name: "Name"
               })

      assert {:ok, repeated} =
               Users.get_or_create_user(
                 Map.merge(attrs, %{
                   email: victim.email,
                   first_name: "Attacker",
                   last_name: "Changed",
                   roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Administrator"],
                   role_id: 999
                 })
               )

      assert repeated.id == user.id
      assert repeated.user.id == local.id
      refute repeated.user.id == victim.id
      assert repeated.user.first_name == "Local"
      assert repeated.user.last_name == "Name"
      assert repeated.user.role_id == local.role_id
    end

    test "new account ignores claimed local user and role IDs", %{
      registration: registration,
      claper_user: claper_user
    } do
      admin_role =
        Claper.Accounts.get_role_by_name("admin") ||
          elem(Claper.Accounts.create_role(%{name: "admin"}), 1)

      attrs = launch_attrs(registration, %{user_id: claper_user.id, role_id: admin_role.id})
      assert {:ok, user} = Users.get_or_create_user(attrs)
      refute user.user_id == claper_user.id
      assert user.user.email == attrs.email
      assert user.user.is_randomized_password
      refute user.user.role_id == admin_role.id
    end

    test "failed identity insert rolls back local account creation", %{registration: registration} do
      attrs = launch_attrs(registration, %{name: nil})
      assert {:error, %{reason: :invalid_user}} = Users.get_or_create_user(attrs)
      assert Claper.Accounts.get_user_by_email(attrs.email) == nil
    end

    test "a different registration cannot reuse an existing identity email", %{
      registration: registration
    } do
      attrs = launch_attrs(registration)
      assert {:ok, original} = Users.get_or_create_user(attrs)
      other_registration = registration_fixture()

      assert {:error, %{reason: :invalid_user}} =
               Users.get_or_create_user(%{attrs | registration_id: other_registration.id})

      assert Claper.Accounts.get_user_by_email(attrs.email).id == original.user_id
    end

    test "deleted local accounts cannot authenticate through their binding", %{
      registration: registration
    } do
      attrs = launch_attrs(registration)
      assert {:ok, user} = Users.get_or_create_user(attrs)
      assert {:ok, _} = Claper.Accounts.delete_user(user.user)
      assert {:error, %{reason: :invalid_user}} = Users.get_or_create_user(attrs)
    end

    test "approval cannot authorize another local account's mapping", %{
      registration: registration,
      claper_user: claper_user
    } do
      other_user = user_fixture(%{password: "a different password"})
      attrs = launch_attrs(registration, %{user_id: other_user.id, email: other_user.email})
      assert {:ok, mapping} = Users.create_user(attrs)

      assert {:error, %{reason: :invalid_user}} =
               Users.authorize_legacy_user(claper_user, mapping.id, valid_user_password())

      assert {:error, %{reason: :invalid_user}} = Users.get_or_create_user(attrs)
      assert Users.get_all_users_by_user_id(claper_user.id) == []
      assert [listed] = Users.get_all_users_by_user_id(other_user.id)
      assert listed.id == mapping.id
      assert listed.registration.issuer == registration.issuer
    end
  end

  defp launch_attrs(registration, overrides \\ %{}) do
    Map.merge(
      %{
        sub: Ecto.UUID.generate(),
        name: "External User",
        first_name: "External",
        last_name: "User",
        email: unique_user_email(),
        roles: ["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
        registration_id: registration.id
      },
      overrides
    )
  end

  describe "authorize_legacy_user/3" do
    defp legacy_mapping(registration, claper_user) do
      {:ok, mapping} =
        Users.create_user(%{
          sub: Ecto.UUID.generate(),
          name: "Legacy",
          email: claper_user.email,
          roles: ["Learner"],
          user_id: claper_user.id,
          registration_id: registration.id
        })

      mapping
    end

    test "refuses legacy mappings on pending platforms" do
      claper_user = user_fixture()
      mapping = legacy_mapping(registration_fixture(%{approved: false}), claper_user)

      assert {:error, %{reason: :invalid_user}} =
               Users.authorize_legacy_user(claper_user, mapping.id, valid_user_password())

      assert Repo.get!(User, mapping.id).authorized_at == nil
    end

    test "rate limits approval attempts per user" do
      claper_user = user_fixture()
      mapping = legacy_mapping(registration_fixture(), claper_user)

      for _ <- 1..5 do
        assert {:error, %{reason: :invalid_user}} =
                 Users.authorize_legacy_user(claper_user, mapping.id, "wrong password")
      end

      assert {:error, %{reason: :rate_limited}} =
               Users.authorize_legacy_user(claper_user, mapping.id, valid_user_password())

      assert Repo.get!(User, mapping.id).authorized_at == nil
    end
  end
end
