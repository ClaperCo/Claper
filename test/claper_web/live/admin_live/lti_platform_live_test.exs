defmodule ClaperWeb.AdminLive.LtiPlatformLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Lti13.RegistrationsFixtures

  alias Claper.Accounts
  alias Lti13.Registrations

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

  describe "as administrator" do
    setup [:register_and_log_in_admin]

    test "lists platforms and approves then revokes them", %{conn: conn, admin: admin} do
      registration = registration_fixture(%{approved: false})
      registrant = Accounts.get_user!(registration.user_id)

      {:ok, view, html} = live(conn, ~p"/admin/lti_platforms")
      assert html =~ registration.issuer
      assert html =~ registration.client_id
      assert html =~ registrant.email
      assert html =~ "Pending"

      view |> element("#approve-lti-registration-#{registration.id}") |> render_click()

      approved = Registrations.get_registration!(registration.id)
      assert Registrations.approved?(approved)
      assert approved.approved_by_id == admin.id
      assert has_element?(view, "#revoke-lti-registration-#{registration.id}")

      view |> element("#revoke-lti-registration-#{registration.id}") |> render_click()

      refute Registrations.approved?(Registrations.get_registration!(registration.id))
    end

    test "a demoted administrator's open page cannot approve", %{conn: conn, admin: admin} do
      registration = registration_fixture(%{approved: false})
      {:ok, view, _html} = live(conn, ~p"/admin/lti_platforms")

      {:ok, _} = Accounts.assign_role(admin, "user")

      assert render_click(view, "approve", %{"id" => to_string(registration.id)}) =~
               "Unable to update LTI platform."

      refute Registrations.approved?(Registrations.get_registration!(registration.id))
    end
  end

  describe "as a regular user" do
    setup :register_and_log_in_user

    test "cannot open the page", %{conn: conn} do
      registration_fixture(%{approved: false})

      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/lti_platforms")
    end
  end
end
