defmodule ClaperWeb.AdminLive.AdminShowTest do
  @moduledoc """
  Covers the unified admin "details card" presentation shared by the
  audit log, user, and event admin show pages.
  """

  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Claper.AuditFixtures
  import Claper.EventsFixtures

  alias Claper.Accounts
  alias Claper.Repo

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

  describe "audit log show" do
    setup [:register_and_log_in_admin]

    test "renders the shared details card with all log fields", %{conn: conn} do
      log =
        log_fixture(%{
          action: "user.login",
          resource_type: "user",
          resource_id: 4242,
          metadata: %{"ip_address" => "127.0.0.1"}
        })

      {:ok, view, html} = live(conn, ~p"/admin/audit_logs/#{log.id}")

      # Shared details card shell
      assert has_element?(view, "dl.card.card-body")
      assert has_element?(view, "dl.card dt", "Action")
      assert has_element?(view, "dl.card dt", "Timestamp")
      assert has_element?(view, "dl.card dt", "Metadata")

      # Preserved semantics: action badge, resource fields, metadata
      assert html =~ "badge"
      assert html =~ "user.login"
      assert html =~ "Resource Type"
      assert html =~ "user"
      assert html =~ "4242"
      assert html =~ "ip_address"
      assert html =~ "127.0.0.1"
    end

    test "omits resource rows when the log has none", %{conn: conn} do
      log = log_fixture(%{resource_type: nil, resource_id: nil, metadata: %{}})

      {:ok, _view, html} = live(conn, ~p"/admin/audit_logs/#{log.id}")

      refute html =~ "Resource Type"
      refute html =~ "Resource ID"
      # Empty metadata renders as the shared placeholder.
      assert html =~ "—"
    end
  end

  describe "user show" do
    setup [:register_and_log_in_admin]

    test "renders the shared details card with confirmed status badge", %{conn: conn} do
      user = confirmed_user_fixture()

      {:ok, view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert has_element?(view, "dl.card.card-body")
      assert has_element?(view, "dl.card dt", "First name")
      assert has_element?(view, "dl.card dt", "Last name")
      assert has_element?(view, "dl.card dt", "Email")
      assert has_element?(view, "dl.card dt", "Status")
      assert has_element?(view, "dl.card dt", "Confirmed At")

      assert html =~ user.email
      assert html =~ user.first_name
      assert html =~ user.last_name
      assert html =~ "badge badge-success"
      assert html =~ "Confirmed"
    end

    test "renders unconfirmed badge and hides confirmed at row when missing", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "badge badge-warning"
      assert html =~ "Unconfirmed"
      refute html =~ "Confirmed At"
    end

    test "renders the audit log section scoped to the user with row links", %{conn: conn} do
      user = confirmed_user_fixture()
      other = confirmed_user_fixture()

      log =
        log_fixture(%{
          user_id: user.id,
          action: "user.login",
          metadata: %{"ip_address" => "10.0.0.1"}
        })

      other_log =
        log_fixture(%{
          user_id: other.id,
          action: "other.action",
          metadata: %{"ip_address" => "10.0.0.2"}
        })

      {:ok, view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "Audit Logs"
      assert html =~ "user.login"
      refute html =~ "other.action"
      assert html =~ "ip_address: 10.0.0.1"

      assert has_element?(
               view,
               ~s|a[href="/admin/audit_logs/#{log.id}"]|
             )

      refute has_element?(
               view,
               ~s|a[href="/admin/audit_logs/#{other_log.id}"]|
             )
    end

    test "renders the empty state when the user has no audit logs", %{conn: conn} do
      user = confirmed_user_fixture()

      {:ok, _view, html} = live(conn, ~p"/admin/users/#{user.id}")

      assert html =~ "Audit Logs"
      assert html =~ "No audit logs for this user."
    end

    test "paginates the user's audit logs", %{conn: conn} do
      user = confirmed_user_fixture()

      logs =
        for index <- 1..3 do
          log_fixture(%{user_id: user.id, action: "user.action.#{index}"})
        end

      {:ok, _view, page_1_html} =
        live(conn, ~p"/admin/users/#{user.id}?#{[page: 1, page_size: 2]}")

      {:ok, _view, page_2_html} =
        live(conn, ~p"/admin/users/#{user.id}?#{[page: 2, page_size: 2]}")

      page_1_matches =
        Enum.count(logs, fn log -> page_1_html =~ log.action end)

      page_2_matches =
        Enum.count(logs, fn log -> page_2_html =~ log.action end)

      assert page_1_matches == 2
      assert page_2_matches == 1
    end

    test "lists the user's events, paginated independently of audit logs", %{conn: conn} do
      user = confirmed_user_fixture()
      for index <- 1..3, do: event_fixture(%{user: user, name: "Owned event #{index}"})
      event_fixture(%{name: "Someone else's event"})

      logs =
        for index <- 1..3 do
          log_fixture(%{user_id: user.id, action: "user.action.#{index}"})
        end

      params = [page: 2, page_size: 2, events: [page: 2, page_size: 2]]
      {:ok, view, html} = live(conn, ~p"/admin/users/#{user.id}?#{params}")

      assert view |> element("#user-events") |> render() =~ "Owned event"
      assert Enum.count(1..3, &(html =~ "Owned event #{&1}")) == 1
      refute html =~ "Someone else&#39;s event"
      assert Enum.count(logs, &(html =~ &1.action)) == 1

      # Paginating events keeps the audit log page and vice versa.
      assert html =~ "/admin/users/#{user.id}?events[page_size]=2&amp;page=2&amp;page_size=2\""

      assert html =~
               "/admin/users/#{user.id}?page_size=2&amp;events[page]=2&amp;events[page_size]=2\""
    end
  end

  describe "user form" do
    setup [:register_and_log_in_admin]

    test "renders first and last name fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/users/new")

      assert has_element?(view, "#user-form input[name='user[first_name]']")
      assert has_element?(view, "#user-form input[name='user[last_name]']")
    end

    test "creates a user with names", %{conn: conn} do
      role = Accounts.get_role_by_name("user")
      email = unique_user_email()
      {:ok, view, _html} = live(conn, ~p"/admin/users/new")

      view
      |> form("#user-form", %{
        "user" => %{
          "first_name" => "Admin",
          "last_name" => "Created",
          "email" => email,
          "password" => valid_user_password(),
          "role_id" => role.id
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")
      user = Accounts.get_user_by_email(email)
      assert user.first_name == "Admin"
      assert user.last_name == "Created"
    end

    test "updates a user's names", %{conn: conn} do
      user = confirmed_user_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/users/#{user.id}/edit")

      view
      |> form("#user-form", %{
        "user" => %{
          "first_name" => "Admin",
          "last_name" => "Updated",
          "email" => user.email,
          "role_id" => user.role_id
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/admin/users")
      updated_user = Accounts.get_user!(user.id)
      assert updated_user.first_name == "Admin"
      assert updated_user.last_name == "Updated"
    end
  end

  describe "event show" do
    setup [:register_and_log_in_admin]

    test "renders the shared details card with owner and timestamps", %{conn: conn} do
      owner = user_fixture(%{email: "owner-#{System.unique_integer([:positive])}@example.com"})

      event =
        event_fixture(%{
          user: owner,
          name: "Admin Show Event",
          started_at: ~N[2026-04-01 10:00:00],
          expired_at: ~N[2026-04-02 10:00:00]
        })

      {:ok, view, html} = live(conn, ~p"/admin/events/#{event.id}")

      assert has_element?(view, "dl.card.card-body")
      assert has_element?(view, "dl.card dt", "Owner")
      assert has_element?(view, "dl.card dt", "Started At")
      assert has_element?(view, "dl.card dt", "Expired At")

      assert html =~ "Admin Show Event"
      assert html =~ owner.email
      assert html =~ "2026-04-01"
      assert html =~ "2026-04-02"
    end

    test "preserves owner and expiration fallbacks when fields are missing", %{conn: conn} do
      # event_fixture creates an owner; bypass the changeset to null
      # user_id and expired_at so we can exercise the fallback strings.
      # started_at is non-null at the DB level so we leave it set.
      event = event_fixture(%{expired_at: nil})

      {1, _} =
        Repo.update_all(
          Ecto.Query.from(e in Claper.Events.Event, where: e.id == ^event.id),
          set: [user_id: nil]
        )

      {:ok, _view, html} = live(conn, ~p"/admin/events/#{event.id}")

      assert html =~ "No owner"
      assert html =~ "Not expired"
    end
  end
end
