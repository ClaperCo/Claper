defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{AccountsFixtures, PostsFixtures, PresentationsFixtures}

  setup [:register_and_log_in_user]

  test "renders the fixed attendee room stack and identity menu", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert "h-[100dvh]" in classes(document, "#attendee-room")
    assert "flex-col" in classes(document, "#attendee-room")
    assert "shrink-0" in classes(document, "#focus-slot")
    assert "flex-1" in classes(document, "#chat-panel")
    assert "z-[60]" in classes(document, "#side-menu")
    assert "h-[40dvh]" in classes(document, "#focus-slot")
    assert Floki.find(document, "#focus-media img") != []
    assert Floki.find(document, "[data-focus-collapse]") != []
    assert Floki.find(document, "[data-focus-show]") != []
    assert document |> Floki.find("[data-focus-show]") |> Floki.text() =~ "Show presentation"
    assert "overflow-y-auto" in classes(document, "#chat-feed")
    assert Floki.attribute(document, "#chat-feed", "phx-hook") == ["RoomFeed"]
    assert Floki.attribute(document, "#post-form", "phx-hook") == ["PostForm"]
    assert "attendee-composer" in classes(document, "#post-form")
    assert Floki.find(document, "#room-topbar") != []
    assert Floki.find(document, "#room-composer") != []
    assert Floki.attribute(document, "[data-reaction-icon]", "draggable") == ["false"]
    assert "pointer-events-none" in classes(document, "[data-reaction-icon]")
    assert Floki.find(document, "#top-identity-button") == []
    assert Floki.find(document, "#composer-identity-button") != []

    [close_command] = Floki.attribute(document, "#nicknamepicker", "data-close")

    assert [["hide", %{"to" => "#identity-menu"}]] = Jason.decode!(close_command)
    assert Floki.attribute(document, "#nicknamepicker", "phx-click") == []
  end

  test "updates reaction controls when message reactions are enabled", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])

    state =
      presentation_state_fixture(%{
        presentation_file: presentation_file,
        message_reaction_enabled: false
      })

    post_fixture(%{event: presentation_file.event, user: user_fixture()})

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    refute html =~ "data-message-reaction-trigger"

    send(view.pid, {:state_updated, %{state | message_reaction_enabled: true}})

    assert render(view) =~ "data-message-reaction-trigger"
  end

  test "does not render the focus panel without attendee content", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user, length: 0}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert Floki.find(document, "#focus-slot") == []
    assert "flex-col" in classes(document, "#attendee-room")
    assert "flex-1" in classes(document, "#chat-panel")
    refute html =~ "Waiting for content"
  end

  test "renders attendee captions as a collapsible panel that cannot be disabled", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _config} =
      Claper.Transcriptions.create_transcription_config(%{
        presentation_file_id: presentation_file.id,
        enabled: true,
        visibility: "attendee"
      })

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert "flex-col" in classes(document, "#attendee-room")
    assert "shrink-0" in classes(document, "#caption-panel")
    assert Floki.attribute(document, "#caption-panel", "phx-hook") == ["AttendeeCaptions"]
    assert Floki.find(document, "[data-caption-collapse]") != []
    assert Floki.find(document, "[data-caption-show]") != []
    assert Floki.find(document, "[data-caption-toggle]") == []
    assert document |> Floki.find("[data-caption-show]") |> Floki.text() =~ "Show captions"

    send(view.pid, {:transcription_delta, "Live caption text"})

    assert view
           |> render()
           |> Floki.parse_document!()
           |> Floki.find("[data-caption-text]")
           |> Floki.text() =~ "Live caption text"
  end

  test "renders the chat panel as a collapsible panel by default", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert Floki.attribute(document, "#chat-panel", "phx-hook") == ["AttendeeChat"]
    assert Floki.find(document, "[data-chat-collapse]") != []
    assert Floki.find(document, "[data-chat-show]") != []
    assert document |> Floki.find("[data-chat-show]") |> Floki.text() =~ "Show messages"
  end

  test "hides the chat panel and composer when the presenter turns the panel off", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])

    presentation_state_fixture(%{
      presentation_file: presentation_file,
      chat_panel_visible: false
    })

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert Floki.find(document, "#chat-panel") == []
    assert Floki.find(document, "#room-composer") == []

    # With no chat panel the focus slot takes the flexible row, so a poll
    # question and its answers use the viewport the panel would have held.
    assert "flex-1" in classes(document, "#focus-slot")
    refute "h-[40dvh]" in classes(document, "#focus-slot")
  end

  test "keeps the chat panel when messages are only deactivated", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])

    presentation_state_fixture(%{
      presentation_file: presentation_file,
      chat_enabled: false
    })

    {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert Floki.find(document, "#chat-panel") != []
    assert Floki.find(document, "#post-form") == []
    assert html =~ "Messages deactivated"
  end

  test "toggles the attendee chat panel live when the presenter switches it", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    state = presentation_state_fixture(%{presentation_file: presentation_file})

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    assert html =~ "chat-panel"

    send(view.pid, {:state_updated, %{state | chat_panel_visible: false}})

    refute render(view) =~ ~s(id="chat-panel")
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
