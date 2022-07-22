defmodule ClaperWeb.EventLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{EventsFixtures}

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  defp create_event(params) do
    event = event_fixture(%{}, [:org])
    params |> Map.put(:event, event) |> Map.put(:org_id, event.org.id)
  end

  describe "Index" do
    setup [:create_event, :register_and_log_in_user]

    test "lists all events", %{conn: conn, event: event} do
      {:ok, _index_live, html} = live(conn, Routes.event_index_path(conn, :index))

      assert html =~ "Listing Events"
      assert html =~ event.name
    end

    test "saves new event", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, Routes.event_index_path(conn, :index))

      assert index_live |> element("a", "New Event") |> render_click() =~
               "New Event"

      assert_patch(index_live, Routes.event_index_path(conn, :new))

      assert index_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#event-form", event: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.event_index_path(conn, :index))

      assert html =~ "Event created successfully"
      assert html =~ "some name"
    end

    test "updates event in listing", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, Routes.event_index_path(conn, :index))

      assert index_live |> element("#event-#{event.uuid} a", "Edit") |> render_click() =~
               "Edit Event"

      assert_patch(index_live, Routes.event_index_path(conn, :edit, event.uuid))

      assert index_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#event-form", event: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.event_index_path(conn, :index))

      assert html =~ "Event updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes event in listing", %{conn: conn, event: event} do
      {:ok, index_live, _html} = live(conn, Routes.event_index_path(conn, :index))

      assert index_live |> element("#event-#{event.uuid} a", "Delete") |> render_click()
      refute has_element?(index_live, "#event-#{event.uuid}")
    end
  end

  describe "Show" do
    setup [:create_event, :register_and_log_in_user]

    test "displays event", %{conn: conn, event: event} do
      {:ok, _show_live, html} = live(conn, Routes.event_show_path(conn, :show, event.uuid))

      assert html =~ "Show Event"
      assert html =~ event.name
    end

    test "updates event within modal", %{conn: conn, event: event} do
      {:ok, show_live, _html} = live(conn, Routes.event_show_path(conn, :show, event.uuid))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Event"

      assert_patch(show_live, Routes.event_show_path(conn, :edit, event.uuid))

      assert show_live
             |> form("#event-form", event: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#event-form", event: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.event_show_path(conn, :show, event.uuid))

      assert html =~ "Event updated successfully"
      assert html =~ "some updated name"
    end
  end
end
