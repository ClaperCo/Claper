defmodule Lti13.RegistrationsTest do
  use Claper.DataCase

  alias Lti13.Registrations

  import Lti13.JwksFixtures
  import Claper.AccountsFixtures

  describe "registrations" do
    test "create and get registration by issuer client id" do
      jwk = jwk_fixture()
      user = confirmed_user_fixture()

      registration = %{
        issuer: "some issuer",
        client_id: "some client_id",
        key_set_url: "some key_set_url",
        auth_token_url: "some auth_token_url",
        auth_login_url: "some auth_login_url",
        auth_server: "some auth_server",
        user_id: user.id,
        tool_jwk_id: jwk.id
      }

      assert {:ok,
              %Registrations.Registration{issuer: "some issuer", client_id: "some client_id"}} =
               Registrations.create_registration(registration)

      assert %Registrations.Registration{issuer: "some issuer", client_id: "some client_id"} =
               Registrations.get_registration_by_issuer_client_id("some issuer", "some client_id")
    end
  end

  describe "approval" do
    import Lti13.RegistrationsFixtures

    setup do
      admin_role =
        Claper.Accounts.get_role_by_name("admin") ||
          elem(Claper.Accounts.create_role(%{name: "admin"}), 1)

      %{admin: user_fixture(%{role_id: admin_role.id})}
    end

    test "approval fields cannot be mass-assigned" do
      registration =
        registration_fixture(%{approved: false, approved_at: ~N[2026-01-01 00:00:00]})

      refute Registrations.approved?(registration)
    end

    test "only administrators can approve or revoke", %{admin: admin} do
      registration = registration_fixture(%{approved: false})

      assert {:error, :unauthorized} =
               Registrations.approve_registration(registration, user_fixture())

      refute Registrations.approved?(Registrations.get_registration!(registration.id))

      assert {:ok, approved} = Registrations.approve_registration(registration, admin)
      assert approved.approved_by_id == admin.id
      assert {:error, :unauthorized} = Registrations.revoke_registration(approved, user_fixture())
      assert {:ok, revoked} = Registrations.revoke_registration(approved, admin)
      refute Registrations.approved?(revoked)
    end

    test "migration backfill approves only administrator registrations", %{admin: admin} do
      migration = Claper.Repo.Migrations.AddApprovalToLtiRegistrations

      unless Code.ensure_loaded?(migration) do
        Code.require_file(
          "priv/repo/migrations/20261026090001_add_approval_to_lti_registrations.exs"
        )
      end

      admin_registration = registration_fixture(%{approved: false, user_id: admin.id})
      user_registration = registration_fixture(%{approved: false})

      Repo.query!(apply(migration, :backfill_sql, []))

      admin_registration = Registrations.get_registration!(admin_registration.id)
      assert admin_registration.approved_at
      assert admin_registration.approved_by_id == admin.id

      user_registration = Registrations.get_registration!(user_registration.id)
      assert user_registration.approved_at == nil
      assert user_registration.approved_by_id == nil
    end
  end
end
