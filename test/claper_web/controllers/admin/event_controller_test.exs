defmodule ClaperWeb.Admin.EventControllerTest do
  use ClaperWeb.ConnCase

  alias Claper.Events
  alias Claper.Accounts
  alias Claper.Admin

  @valid_event_attrs %{
    name: "Test Event",
    description: "Test event description",
    start_date: ~N[2023-01-01 10:00:00],
    end_date: ~N[2023-01-01 12:00:00],
    timezone: "UTC",
    status: "active"
  }
  @update_attrs %{
    name: "Updated Event",
    description: "Updated description",
    status: "completed"
  }
  @invalid_attrs %{name: nil, description: nil, start_date: nil}

  setup do
    # Create roles
    {:ok, user_role} = Accounts.create_role(%{name: "user"})
    {:ok, admin_role} = Accounts.create_role(%{name: "admin"})

    # Create an admin user
    {:ok, admin} = Accounts.create_user(%{email: "admin@example.com", password: "Password123!"})
    {:ok, admin} = Accounts.assign_role(admin, admin_role)

    # Create a test event
    {:ok, event} = Events.create_event(@valid_event_attrs)

    # Create a conn with admin logged in
    admin_conn =
      build_conn()
      |> Map.replace!(:secret_key_base, ClaperWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})
      |> Accounts.Guardian.Plug.sign_in(admin)

    %{admin: admin, event: event, admin_conn: admin_conn}
  end

  describe "index" do
    test "lists all events", %{admin_conn: conn, event: event} do
      conn = get(conn, Routes.admin_event_path(conn, :index))
      assert html_response(conn, 200) =~ "Events Management"
      assert html_response(conn, 200) =~ event.name
    end

    test "exports events as CSV", %{admin_conn: conn, event: event} do
      conn = get(conn, Routes.admin_event_path(conn, :index, format: "csv"))

      assert response_content_type(conn, :csv)
      assert response(conn, 200) =~ "Name,Description,Start Date,End Date,Status"
      assert response(conn, 200) =~ event.name
    end
  end

  describe "new event" do
    test "renders form", %{admin_conn: conn} do
      conn = get(conn, Routes.admin_event_path(conn, :new))
      assert html_response(conn, 200) =~ "New Event"
    end
  end

  describe "create event" do
    test "redirects to show when data is valid", %{admin_conn: conn} do
      new_event_attrs = Map.put(@valid_event_attrs, :name, "New Test Event")
      conn = post(conn, Routes.admin_event_path(conn, :create), event: new_event_attrs)

      assert %{id: id} = redirected_params(conn)
      assert redirected_to(conn) == Routes.admin_event_path(conn, :show, id)

      conn = get(conn, Routes.admin_event_path(conn, :show, id))
      assert html_response(conn, 200) =~ "New Test Event"
    end

    test "renders errors when data is invalid", %{admin_conn: conn} do
      conn = post(conn, Routes.admin_event_path(conn, :create), event: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Event"
      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "validates event data before creating", %{admin_conn: conn} do
      invalid_date_attrs =
        Map.merge(@valid_event_attrs, %{
          name: "Invalid Date Event",
          start_date: ~N[2023-01-01 12:00:00],
          # End before start
          end_date: ~N[2023-01-01 10:00:00]
        })

      conn = post(conn, Routes.admin_event_path(conn, :create), event: invalid_date_attrs)
      assert html_response(conn, 200) =~ "New Event"
      assert html_response(conn, 200) =~ "End date must be after start date"
    end
  end

  describe "edit event" do
    test "renders form for editing chosen event", %{admin_conn: conn, event: event} do
      conn = get(conn, Routes.admin_event_path(conn, :edit, event))
      assert html_response(conn, 200) =~ "Edit Event"
      assert html_response(conn, 200) =~ event.name
    end
  end

  describe "update event" do
    test "redirects when data is valid", %{admin_conn: conn, event: event} do
      conn = put(conn, Routes.admin_event_path(conn, :update, event), event: @update_attrs)
      assert redirected_to(conn) == Routes.admin_event_path(conn, :show, event)

      conn = get(conn, Routes.admin_event_path(conn, :show, event))
      assert html_response(conn, 200) =~ "Updated Event"
      assert html_response(conn, 200) =~ "Updated description"
    end

    test "renders errors when data is invalid", %{admin_conn: conn, event: event} do
      conn = put(conn, Routes.admin_event_path(conn, :update, event), event: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Event"
      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "validates event data before updating", %{admin_conn: conn, event: event} do
      invalid_date_attrs = %{
        start_date: ~N[2023-01-01 12:00:00],
        # End before start
        end_date: ~N[2023-01-01 10:00:00]
      }

      conn = put(conn, Routes.admin_event_path(conn, :update, event), event: invalid_date_attrs)
      assert html_response(conn, 200) =~ "Edit Event"
      assert html_response(conn, 200) =~ "End date must be after start date"
    end
  end

  describe "delete event" do
    test "deletes chosen event", %{admin_conn: conn, event: event} do
      conn = delete(conn, Routes.admin_event_path(conn, :delete, event))
      assert redirected_to(conn) == Routes.admin_event_path(conn, :index)

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_event!(event.id)
      end
    end
  end
end
