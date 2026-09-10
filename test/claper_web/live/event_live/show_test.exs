defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{AccountsFixtures, PollsFixtures, PostsFixtures, PresentationsFixtures}

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
    assert "grid-rows-[auto_auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
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
    assert "grid-rows-[auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
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

    assert "grid-rows-[auto_auto_auto_minmax(0,1fr)]" in classes(document, "#attendee-room")
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

  test "rates a slider poll and shows the average once voted", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll_fixture(%{
      presentation_file_id: presentation_file.id,
      position: 0,
      enabled: true,
      show_results: true,
      type: :slider,
      min_value: 1,
      max_value: 10,
      min_label: "Poor",
      max_label: "Excellent",
      poll_opts: []
    })

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    document = Floki.parse_document!(html)

    assert html =~ "Drag the slider to rate"
    assert html =~ "Poor"
    assert html =~ "Excellent"
    assert Floki.attribute(document, "#extended-poll input[type=range]", "min") == ["1"]
    assert Floki.attribute(document, "#extended-poll input[type=range]", "max") == ["10"]
    assert Floki.attribute(document, "#extended-poll input[type=range]", "value") == ["5"]

    view
    |> element("#extended-poll form")
    |> render_submit(%{"value" => "8"})

    # the vote is broadcast back on the event topic, which refreshes the poll
    html = render(view)

    assert html =~ "Average rating"
    assert html =~ "8.0"

    # the slider is gone once the attendee has rated
    assert html |> Floki.parse_document!() |> Floki.find("#extended-poll input[type=range]") == []
  end

  test "keeps the slider average to itself when the presenter disabled attendee results", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll_fixture(%{
      presentation_file_id: presentation_file.id,
      position: 0,
      enabled: true,
      show_results: false,
      type: :slider,
      min_value: 1,
      max_value: 10,
      poll_opts: []
    })

    {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    view
    |> element("#extended-poll form")
    |> render_submit(%{"value" => "8"})

    html = render(view)

    assert html =~ "Thanks"
    refute html =~ "Average rating"
    refute html =~ "8.0"
  end

  test "ignores a rating pushed at a choice poll", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll =
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :choice
      })

    {:ok, view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    refute html =~ ~s(type="range")

    render_hook(view, "submit-rating", %{"value" => "7"})

    assert Enum.map(Claper.Polls.get_poll!(poll.id).poll_opts, & &1.content) == [
             "some option 1",
             "some option 2"
           ]
  end

  test "ignores an option vote pushed at a slider poll", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll =
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :slider,
        min_value: 1,
        max_value: 10,
        poll_opts: []
      })

    {:ok, _} =
      Claper.Polls.submit_rating("someone-else", presentation_file.event.uuid, poll.id, "7")

    {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    render_hook(view, "select-poll-opt", %{"opt" => "0"})
    render_hook(view, "vote", %{})

    assert render(view) =~ "range"
    assert [%{content: "7", vote_count: 1}] = Claper.Polls.get_poll!(poll.id).poll_opts
    assert Claper.Polls.get_poll_vote(user.id, poll.id) == []
  end

  test "survives an option vote pushed at a slider poll nobody has rated yet", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll =
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :slider,
        min_value: 1,
        max_value: 10,
        poll_opts: []
      })

    {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    render_hook(view, "select-poll-opt", %{"opt" => "0"})
    render_hook(view, "vote", %{})

    assert render(view) =~ "range"
    assert Claper.Polls.get_poll!(poll.id).poll_opts == []
    assert Claper.Polls.get_poll_vote(user.id, poll.id) == []
  end

  test "counts a second rating push from the same attendee only once", %{conn: conn, user: user} do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})

    poll =
      poll_fixture(%{
        presentation_file_id: presentation_file.id,
        position: 0,
        enabled: true,
        type: :slider,
        min_value: 1,
        max_value: 10,
        poll_opts: []
      })

    {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    render_hook(view, "submit-rating", %{"value" => "8"})
    render_hook(view, "submit-rating", %{"value" => "2"})

    assert [%{content: "8", vote_count: 1}] = Claper.Polls.get_poll!(poll.id).poll_opts
    assert length(Claper.Polls.get_poll_vote(user.id, poll.id)) == 1
    refute render(view) =~ ~s(type="range")
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
