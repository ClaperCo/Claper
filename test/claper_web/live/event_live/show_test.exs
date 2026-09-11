defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  import Claper.{
    AccountsFixtures,
    FormsFixtures,
    PollsFixtures,
    PostsFixtures,
    PresentationsFixtures
  }

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

  describe "submit-word" do
    test "adds the word when the current interaction is an enabled word cloud poll", %{
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
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_hook(view, "submit-word", %{"word" => "inspiring"})

      assert [%{content: "inspiring", vote_count: 1}] = Claper.Polls.get_poll!(poll.id).poll_opts
    end

    test "is ignored when the current interaction is a choice poll", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          position: 0,
          enabled: true,
          type: :choice
        })

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_hook(view, "submit-word", %{"word" => "injected"})

      contents = Enum.map(Claper.Polls.get_poll!(poll.id).poll_opts, & &1.content)

      assert contents == ["some option 1", "some option 2"]
      refute "injected" in contents
    end

    test "is ignored, without crashing, when the current interaction is a form", %{
      conn: conn,
      user: user
    } do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      form_fixture(%{presentation_file_id: presentation_file.id, position: 0, enabled: true})

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_hook(view, "submit-word", %{"word" => "injected"})

      assert render(view) =~ "some title"
      assert Claper.Repo.aggregate(Claper.Polls.PollOpt, :count) == 0
    end

    test "tells the attendee when their word was rejected", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          position: 0,
          enabled: true,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      html = render_hook(view, "submit-word", %{"word" => "   "})

      assert Claper.Polls.get_poll!(poll.id).poll_opts == []
      assert html =~ "Your word could not be added"
    end

    test "is ignored when the word cloud poll is disabled", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          position: 0,
          enabled: false,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_hook(view, "submit-word", %{"word" => "injected"})

      assert Claper.Polls.get_poll!(poll.id).poll_opts == []
    end
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
