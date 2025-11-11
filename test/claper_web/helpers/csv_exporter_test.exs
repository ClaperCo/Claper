defmodule ClaperWeb.Helpers.CSVExporterTest do
  use Claper.DataCase

  alias ClaperWeb.Helpers.CSVExporter
  alias Claper.Accounts.User
  alias Claper.Events.Event
  alias Claper.Accounts.Oidc.Provider
  alias Claper.Accounts.Role
  alias Claper.Repo

  describe "export_users_to_csv/1" do
    setup do
      # Create roles
      {:ok, user_role} = Repo.insert(%Role{name: "user"})
      {:ok, admin_role} = Repo.insert(%Role{name: "admin"})

      # Create users
      {:ok, user1} =
        Repo.insert(%User{
          email: "user1@example.com",
          uuid: Ecto.UUID.generate(),
          role_id: user_role.id,
          inserted_at: ~N[2023-01-01 10:00:00],
          hashed_password: "hashed_password",
          is_randomized_password: false
        })

      {:ok, user2} =
        Repo.insert(%User{
          email: "admin@example.com",
          uuid: Ecto.UUID.generate(),
          role_id: admin_role.id,
          inserted_at: ~N[2023-01-02 10:00:00],
          hashed_password: "hashed_password",
          is_randomized_password: false
        })

      %{users: [user1, user2], user_role: user_role, admin_role: admin_role}
    end

    test "exports users to CSV format", %{users: users} do
      users = Repo.preload(users, :role)
      csv = CSVExporter.export_users_to_csv(users)

      # CSV should have a header row and two data rows
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 3

      # Check header
      header = List.first(lines)
      assert header =~ "Email"
      assert header =~ "Name"
      assert header =~ "Role"
      assert header =~ "Created At"

      # Check data rows
      assert Enum.at(lines, 1) =~ "user1@example.com"
      assert Enum.at(lines, 1) =~ "user"

      assert Enum.at(lines, 2) =~ "admin@example.com"
      assert Enum.at(lines, 2) =~ "admin"
    end

    test "handles empty user list" do
      csv = CSVExporter.export_users_to_csv([])

      # CSV should only have a header row
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 1

      # Check header
      header = List.first(lines)
      assert header =~ "Email"
      assert header =~ "Name"
      assert header =~ "Role"
    end
  end

  describe "export_events_to_csv/1" do
    setup do
      # Create events
      {:ok, event1} =
        Repo.insert(%Event{
          name: "Event One",
          uuid: Ecto.UUID.generate(),
          code: "event1",
          started_at: ~N[2023-01-01 10:00:00],
          expired_at: ~N[2023-01-01 12:00:00],
          audience_peak: 10,
          inserted_at: ~N[2023-01-01 09:00:00]
        })

      {:ok, event2} =
        Repo.insert(%Event{
          name: "Event Two",
          uuid: Ecto.UUID.generate(),
          code: "event2",
          started_at: ~N[2023-01-02 10:00:00],
          expired_at: ~N[2023-01-02 12:00:00],
          audience_peak: 20,
          inserted_at: ~N[2023-01-01 09:30:00]
        })

      %{events: [event1, event2]}
    end

    test "exports events to CSV format", %{events: events} do
      csv = CSVExporter.export_events_to_csv(events)

      # CSV should have a header row and two data rows
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 3

      # Check header
      header = List.first(lines)
      assert header =~ "Name"
      assert header =~ "Description"
      assert header =~ "Start Date"
      assert header =~ "End Date"
      assert header =~ "Status"

      # Check data rows contain event names
      assert Enum.at(lines, 1) =~ "Event One"
      assert Enum.at(lines, 2) =~ "Event Two"
    end

    test "handles empty event list" do
      csv = CSVExporter.export_events_to_csv([])

      # CSV should only have a header row
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 1

      # Check header
      header = List.first(lines)
      assert header =~ "Name"
      assert header =~ "Description"
      assert header =~ "Start Date"
    end
  end

  describe "export_oidc_providers_to_csv/1" do
    setup do
      # Create providers
      {:ok, provider1} =
        Repo.insert(%Provider{
          name: "Provider One",
          issuer: "https://example1.com",
          client_id: "client1",
          client_secret: "secret1",
          redirect_uri: "https://app.example.com/callback1",
          scope: "openid email",
          active: true,
          inserted_at: ~N[2023-01-01 09:00:00]
        })

      {:ok, provider2} =
        Repo.insert(%Provider{
          name: "Provider Two",
          issuer: "https://example2.com",
          client_id: "client2",
          client_secret: "secret2",
          redirect_uri: "https://app.example.com/callback2",
          scope: "openid profile",
          active: false,
          inserted_at: ~N[2023-01-01 09:30:00]
        })

      %{providers: [provider1, provider2]}
    end

    test "exports providers to CSV format", %{providers: providers} do
      csv = CSVExporter.export_oidc_providers_to_csv(providers)

      # CSV should have a header row and two data rows
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 3

      # Check header
      header = List.first(lines)
      assert header =~ "Name"
      assert header =~ "Issuer"
      assert header =~ "Client ID"
      assert header =~ "Active"

      # Client secret should not be included for security
      refute header =~ "Client Secret"

      # Check data rows
      assert Enum.at(lines, 1) =~ "Provider One"
      assert Enum.at(lines, 1) =~ "https://example1.com"
      assert Enum.at(lines, 1) =~ "client1"
      assert Enum.at(lines, 1) =~ "Yes"

      assert Enum.at(lines, 2) =~ "Provider Two"
      assert Enum.at(lines, 2) =~ "https://example2.com"
      assert Enum.at(lines, 2) =~ "client2"
      assert Enum.at(lines, 2) =~ "No"

      # Client secrets should not be included in the CSV
      refute csv =~ "secret1"
      refute csv =~ "secret2"
    end

    test "handles empty provider list" do
      csv = CSVExporter.export_oidc_providers_to_csv([])

      # CSV should only have a header row
      lines = String.split(csv, "\r\n", trim: true)
      assert length(lines) == 1

      # Check header
      header = List.first(lines)
      assert header =~ "Name"
      assert header =~ "Issuer"
      assert header =~ "Client ID"
    end
  end
end
