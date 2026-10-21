defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{AccountsFixtures, PostsFixtures, PresentationsFixtures}

  alias Claper.Posts

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

  describe "authenticated_chat_only" do
    test "replaces the composer with a log in prompt for anonymous attendees", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, _view, html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      document = Floki.parse_document!(html)

      assert Floki.find(document, "#post-form") == []
      assert Floki.find(document, "#login-required-composer") != []
      assert html =~ "Log in to post a message"
    end

    test "takes the identity panel down with the gated composer", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, _view, html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      document = Floki.parse_document!(html)

      assert Floki.find(document, "#login-required-composer") != []
      assert Floki.find(document, "#identity-menu") == []
      assert Floki.find(document, "#nicknamepicker") == []
      assert Floki.find(document, "#setAnonymous") == []
    end

    test "takes the identity panel down while messages are disabled", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: false
      })

      {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      document = Floki.parse_document!(html)

      assert Floki.find(document, "#post-form") == []
      assert Floki.find(document, "#identity-menu") == []
      assert Floki.find(document, "#nicknamepicker") == []
    end

    test "brings the attendee back to the event after logging in", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, _view, html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      [login_href] =
        html
        |> Floki.parse_document!()
        |> Floki.attribute("#login-required-composer a", "href")

      attendee = user_fixture()

      conn =
        build_conn()
        |> get(login_href)
        |> post(~p"/users/log_in", %{
          "user" => %{"email" => attendee.email, "password" => valid_user_password()}
        })

      assert redirected_to(conn) == ~p"/e/#{presentation_file.event.code}"
    end

    test "keeps the composer for logged in attendees", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, _view, html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      document = Floki.parse_document!(html)

      assert Floki.find(document, "#post-form") != []
      assert Floki.find(document, "#login-required-composer") == []
    end

    test "rejects a message pushed by an anonymous attendee", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, view, _html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      html = render_click(view, "save", %{"post" => %{"body" => "troll message"}})

      assert html =~ "You must be logged in to post a message"
      assert Posts.list_posts(presentation_file.event.uuid) == []
    end

    test "rejects a message an anonymous attendee signs with a foreign user id", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      state =
        presentation_state_fixture(%{
          presentation_file: presentation_file,
          chat_enabled: true,
          anonymous_chat_enabled: true,
          authenticated_chat_only: false
        })

      {:ok, view, _html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      # The moderator turns the setting on while the attendee still holds the
      # state it mounted with, so the LiveView clause cannot catch this one.
      state
      |> Ecto.Changeset.change(authenticated_chat_only: true)
      |> Claper.Repo.update!()

      html =
        render_click(view, "save", %{
          "post" => %{"body" => "troll message", "user_id" => user.id}
        })

      assert Posts.list_posts(presentation_file.event.uuid) == []
      assert html =~ "You must be logged in to post a message"
    end

    test "accepts a message from a logged in attendee", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        anonymous_chat_enabled: true,
        authenticated_chat_only: true
      })

      {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_click(view, "save", %{"post" => %{"body" => "a legitimate question"}})

      assert [%{body: "a legitimate question", user_id: user_id}] =
               Posts.list_posts(presentation_file.event.uuid)

      assert user_id == user.id
    end

    test "swaps the composer when the moderator turns it on mid-session", %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      state =
        presentation_state_fixture(%{
          presentation_file: presentation_file,
          chat_enabled: true,
          authenticated_chat_only: false
        })

      {:ok, view, html} = live(build_conn(), ~p"/e/#{presentation_file.event.code}")

      assert Floki.find(Floki.parse_document!(html), "#post-form") != []

      send(view.pid, {:state_updated, %{state | authenticated_chat_only: true}})

      document = view |> render() |> Floki.parse_document!()

      assert Floki.find(document, "#post-form") == []
      assert Floki.find(document, "#login-required-composer") != []
    end
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
