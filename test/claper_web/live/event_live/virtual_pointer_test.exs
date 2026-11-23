defmodule ClaperWeb.EventLive.VirtualPointerTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PresentationsFixtures

  alias Claper.Presentations

  setup [:register_and_log_in_user]

  setup %{user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 2}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    %{presentation_file: presentation_file, event: presentation_file.event}
  end

  test "the manage view offers a toggle over the slide preview", %{conn: conn, event: event} do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")

    assert has_element?(manager, ~s(#slide-pointer[phx-hook="PointerSender"]))
    assert has_element?(manager, "#slide-pointer button[data-pointer-toggle]")
    assert has_element?(manager, "#slide-pointer [data-pointer-surface]")
    assert has_element?(manager, "#slide-pointer [data-pointer-host] [data-pointer-dot]")
  end

  test "the projected presentation has a pointer overlay", %{conn: conn, event: event} do
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")

    assert has_element?(presenter, ~s(#presenter-pointer[phx-hook="PointerOverlay"]))
    assert has_element?(presenter, "#presenter-pointer [data-pointer-dot]")
  end

  test "the pointer moved in the manage view reaches the projected presentation and attendees",
       %{conn: conn, event: event} do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    {:ok, attendee, _html} = live(build_conn(), ~p"/e/#{event.code}")

    render_hook(manager, "pointer-move", %{"x" => 0.25, "y" => 0.5})

    assert_push_event(presenter, "pointer", %{visible: true, x: 0.25, y: 0.5})
    assert_push_event(attendee, "pointer", %{visible: true, x: 0.25, y: 0.5})
  end

  test "the pointer steered from the presenter window reaches the attendees", %{
    conn: conn,
    event: event
  } do
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    {:ok, attendee, _html} = live(build_conn(), ~p"/e/#{event.code}")

    assert has_element?(presenter, "#presenter-pointer[data-pointer-control]")

    render_hook(presenter, "pointer-move", %{"x" => 0.4, "y" => 0.6})
    assert_push_event(attendee, "pointer", %{visible: true, x: 0.4, y: 0.6})

    render_hook(presenter, "pointer-hide", %{})
    assert_push_event(attendee, "pointer", %{visible: false})
  end

  test "values from the presenter window are validated and tagged with their sender",
       %{conn: conn, event: event, presentation_file: presentation_file} do
    Presentations.subscribe(presentation_file.id)
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")

    render_hook(presenter, "pointer-move", %{"x" => 2, "y" => 0.5})
    refute_receive {:pointer_moved, _}

    render_hook(presenter, "pointer-move", %{"x" => 0.1, "y" => 0.9})
    assert_receive {:pointer_moved, %{x: 0.1, y: 0.9, position: 0, source: source}}
    assert source == presenter.pid
  end

  test "hiding the pointer in the manage view hides it everywhere", %{conn: conn, event: event} do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    {:ok, attendee, _html} = live(build_conn(), ~p"/e/#{event.code}")

    render_hook(manager, "pointer-hide", %{})

    assert_push_event(presenter, "pointer", %{visible: false})
    assert_push_event(attendee, "pointer", %{visible: false})
  end

  test "changing slide hides the pointer", %{
    conn: conn,
    event: event,
    presentation_file: presentation_file
  } do
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")
    {:ok, attendee, _html} = live(build_conn(), ~p"/e/#{event.code}")

    {:ok, _state} =
      Presentations.update_presentation_state(presentation_state(presentation_file), %{
        position: 1
      })

    assert_push_event(presenter, "pointer", %{visible: false})
    assert_push_event(attendee, "pointer", %{visible: false})
  end

  test "the pointer follows the slide the presenter is on", %{
    conn: conn,
    event: event,
    presentation_file: presentation_file
  } do
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")
    {:ok, presenter, _html} = live(conn, ~p"/e/#{event.code}/presenter")

    render_hook(manager, "current-page", %{"page" => "1"})
    assert presentation_state(presentation_file).position == 1

    render_hook(manager, "pointer-move", %{"x" => 0.8, "y" => 0.2})

    assert_push_event(presenter, "pointer", %{visible: true, x: 0.8, y: 0.2})
  end

  test "values outside the slide are never broadcast", %{
    conn: conn,
    event: event,
    presentation_file: presentation_file
  } do
    Presentations.subscribe(presentation_file.id)
    {:ok, manager, _html} = live(conn, ~p"/e/#{event.code}/manage")

    render_hook(manager, "pointer-move", %{"x" => 2, "y" => 0.5})
    render_hook(manager, "pointer-move", %{"x" => "left", "y" => 0.5})
    refute_receive {:pointer_moved, _}

    render_hook(manager, "pointer-move", %{"x" => 1, "y" => 0})
    assert_receive {:pointer_moved, %{x: 1, y: 0, position: 0}}
  end

  defp presentation_state(presentation_file) do
    Presentations.get_presentation_file!(presentation_file.id, [:presentation_state]).presentation_state
  end
end
