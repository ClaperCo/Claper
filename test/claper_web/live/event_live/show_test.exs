defmodule ClaperWeb.EventLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  import Claper.{
    AccountsFixtures,
    FormsFixtures,
    PollsFixtures,
    PostsFixtures,
    PresentationsFixtures,
    WordCloudsFixtures
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

  test "ignores poll clicks that arrive after the presenter switched to another interaction", %{
    conn: conn,
    user: user
  } do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    poll = poll_fixture(%{presentation_file_id: presentation_file.id})

    {:ok, view, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

    assert has_element?(view, "#poll-opt-0")

    form = form_fixture(%{presentation_file_id: presentation_file.id, enabled: false})
    :ok = Claper.Interactions.enable_interaction(form)
    send(view.pid, {:current_interaction, form})

    for _attempt <- 1..3 do
      render_hook(view, "select-poll-opt", %{"opt" => "0"})
      render_hook(view, "vote", %{})
    end

    refute has_element?(view, "#poll-opt-0")
    assert Claper.Polls.get_poll_vote(user.id, poll.id) == []
    assert submission_audits_for_event("poll", presentation_file.event.id) == []
  end

  describe "attendee messages" do
    setup %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      state =
        presentation_state_fixture(%{
          presentation_file: presentation_file,
          position: 2,
          chat_enabled: true,
          anonymous_chat_enabled: true
        })

      foreign_presentation = presentation_file_fixture(%{}, [:event])
      victim = user_fixture()

      forged_post = %{
        "body" => "A real attendee message",
        "user_id" => victim.id,
        "attendee_identifier" => "someone-else",
        "name" => "Forged moderator",
        "position" => 999,
        "pinned" => true,
        "like_count" => 900,
        "love_count" => 800,
        "lol_count" => 700,
        "event_id" => foreign_presentation.event.id
      }

      %{
        event: presentation_file.event,
        state: state,
        forged_post: forged_post,
        foreign_event: foreign_presentation.event
      }
    end

    test "anonymous submissions cannot forge attribution, moderation, or reactions", %{
      event: event,
      forged_post: forged_post,
      foreign_event: foreign_event
    } do
      conn = build_conn() |> init_test_session(%{attendee_identifier: "actual-attendee"})
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")
      render_submit(view, "save-nickname", %{"post" => %{"name" => "Actual nickname"}})

      for _attempt <- 1..3 do
        render_submit(view, "save", %{"post" => forged_post})
      end

      posts = Claper.Posts.list_posts(event.uuid)
      assert length(posts) == 3

      for post <- posts do
        assert post.body == forged_post["body"]
        assert post.user_id == nil
        assert post.attendee_identifier == "actual-attendee"
        assert post.name == "Actual nickname"
        assert post.position == 2
        assert post.event_id == event.id
        refute post.pinned
        assert {post.like_count, post.love_count, post.lol_count} == {0, 0, 0}
      end

      assert Claper.Posts.list_posts(foreign_event.uuid) == []
      assert [audit] = submission_audits_for_event("message", event.id)
      assert audit.user_id == nil
      assert audit.metadata["reason"] == "forged_fields"
      assert is_binary(audit.metadata["attendee_fingerprint"])
      metadata = Jason.encode!(audit.metadata)
      refute metadata =~ "actual-attendee"
      refute metadata =~ forged_post["body"]
      refute metadata =~ forged_post["name"]
      refute Map.has_key?(audit.metadata, "user_id")
    end

    test "signed-in submissions cannot add anonymous identity or privileged fields", %{
      event: event,
      forged_post: forged_post,
      foreign_event: foreign_event
    } do
      participant = confirmed_user_fixture()
      conn = build_conn() |> log_in_user(participant)
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")
      render_submit(view, "save-nickname", %{"post" => %{"name" => "Signed nickname"}})

      for _attempt <- 1..3 do
        render_submit(view, "save", %{"post" => forged_post})
      end

      posts = Claper.Posts.list_posts(event.uuid)
      assert length(posts) == 3

      for post <- posts do
        assert post.user_id == participant.id
        assert post.attendee_identifier == nil
        assert post.name == "Signed nickname"
        assert post.position == 2
        assert post.event_id == event.id
        refute post.pinned
        assert {post.like_count, post.love_count, post.lol_count} == {0, 0, 0}
      end

      assert Claper.Posts.list_posts(foreign_event.uuid) == []
      assert [audit] = submission_audits_for_event("message", event.id)
      assert audit.user_id == participant.id
      assert audit.metadata["reason"] == "forged_fields"
      refute Map.has_key?(audit.metadata, "user_id")
      refute Jason.encode!(audit.metadata) =~ forged_post["body"]
    end

    test "disabled chat rejects direct save events for both identities", %{
      conn: conn,
      event: event,
      state: state,
      forged_post: forged_post
    } do
      {:ok, _state} =
        Claper.Presentations.update_presentation_state(state, %{chat_enabled: false})

      anonymous_conn =
        build_conn() |> init_test_session(%{attendee_identifier: "disabled-chat-attendee"})

      for attendee_conn <- [anonymous_conn, conn] do
        audits_before = length(submission_audits_for_event("message", event.id))
        {:ok, view, _html} = live(attendee_conn, ~p"/e/#{event.code}")

        for _attempt <- 1..2 do
          render_submit(view, "save", %{"post" => Map.take(forged_post, ["body"])})
          assert length(submission_audits_for_event("message", event.id)) == audits_before
        end

        render_submit(view, "save", %{"post" => Map.take(forged_post, ["body"])})
        assert length(submission_audits_for_event("message", event.id)) == audits_before + 1
      end

      assert Claper.Posts.list_posts(event.uuid) == []
      audits = submission_audits_for_event("message", event.id)
      assert length(audits) == 2

      for audit <- audits do
        assert audit.metadata["reason"] == "chat_disabled"
        assert audit.metadata["observed_count"] == 3
        refute Jason.encode!(audit.metadata) =~ forged_post["body"]
        refute Jason.encode!(audit.metadata) =~ "disabled-chat-attendee"
      end
    end

    test "a stale enabled socket cannot bypass newly disabled chat", %{
      conn: conn,
      event: event,
      state: state,
      forged_post: forged_post
    } do
      {:ok, signed_view, _html} = live(conn, ~p"/e/#{event.code}")
      {:ok, anonymous_view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      # Deliberately skip PubSub so both sockets retain the old enabled state.
      state |> Ecto.Changeset.change(chat_enabled: false) |> Claper.Repo.update!()

      for view <- [signed_view, anonymous_view] do
        render_submit(view, "save", %{"post" => forged_post})
      end

      assert Claper.Posts.list_posts(event.uuid) == []
    end

    test "nickname requirements use current state rather than forged names or stale sockets", %{
      conn: conn,
      event: event,
      state: state,
      forged_post: forged_post
    } do
      {:ok, signed_view, _html} = live(conn, ~p"/e/#{event.code}")
      {:ok, anonymous_view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      state |> Ecto.Changeset.change(anonymous_chat_enabled: false) |> Claper.Repo.update!()

      for view <- [signed_view, anonymous_view] do
        render_submit(view, "save", %{"post" => forged_post})
      end

      assert Claper.Posts.list_posts(event.uuid) == []
      render_submit(anonymous_view, "save-nickname", %{"post" => %{"name" => "Allowed name"}})
      render_submit(anonymous_view, "save", %{"post" => forged_post})
      assert [%{name: "Allowed name", user_id: nil}] = Claper.Posts.list_posts(event.uuid)
    end

    test "the persisted slide position wins over stale assigns and submitted position", %{
      conn: conn,
      event: event,
      state: state,
      forged_post: forged_post
    } do
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")
      state |> Ecto.Changeset.change(position: 4) |> Claper.Repo.update!()
      render_submit(view, "save", %{"post" => forged_post})

      assert [%{position: 4}] = Claper.Posts.list_posts(event.uuid)
    end

    test "ordinary message fields and repeated content validation do not raise observations", %{
      conn: conn,
      event: event
    } do
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")
      render_submit(view, "save-nickname", %{"post" => %{"name" => "Attendee"}})

      for _attempt <- 1..3 do
        view
        |> form("#post-form", %{post: %{body: "Ordinary message"}})
        |> render_submit()

        render_submit(view, "save", %{
          "post" => %{"body" => "Another message", "name" => "Attendee"}
        })

        render_submit(view, "save", %{"post" => %{"body" => ""}})
      end

      assert length(Claper.Posts.list_posts(event.uuid)) == 6
      assert submission_audits_for_event("message", event.id) == []
    end

    test "accepted message bursts are observed without rejecting or recording content", %{
      conn: conn,
      user: user,
      event: event
    } do
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      for number <- 1..19 do
        render_submit(view, "save", %{"post" => %{"body" => "Private accepted message #{number}"}})
      end

      assert submission_audits_for_event("message", event.id) == []

      for number <- 20..21 do
        render_submit(view, "save", %{"post" => %{"body" => "Private accepted message #{number}"}})
      end

      assert length(Claper.Posts.list_posts(event.uuid)) == 21
      assert [audit] = submission_audits_for_event("message", event.id)
      assert audit.user_id == user.id
      assert audit.metadata["reason"] == "submission_burst"
      assert audit.metadata["observed_count"] == 20
      refute Jason.encode!(audit.metadata) =~ "Private accepted message"
    end
  end

  describe "word cloud" do
    setup %{user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})

      %{presentation_file: presentation_file, event: presentation_file.event}
    end

    test "an anonymous attendee sees results before submitting and can still send a word", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Quokka"})

      {:ok, view, html} = live(build_conn(), ~p"/e/#{event.code}")

      assert html =~ "One word"
      assert has_element?(view, ~s(form[phx-submit="submit-word"] input[name="word"]))
      assert attendee_cloud(view, word_cloud) == ["Quokka"]

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "  Elixir "})
      |> render_submit()

      refute has_element?(view, ~s(form[phx-submit="submit-word"]))
      assert has_element?(view, "[data-submitted]")
      assert attendee_cloud(view, word_cloud) == ["Elixir", "Quokka"]

      assert [_quokka, %{content: "Elixir", attendee_identifier: identifier, user_id: nil}] =
               Claper.WordClouds.list_entries(word_cloud.id)

      assert is_binary(identifier)
    end

    test "a signed-in attendee's word is stored under their account", %{
      conn: conn,
      user: user,
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)

      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
      |> render_submit()

      assert [%{user_id: user_id, attendee_identifier: nil}] =
               Claper.WordClouds.list_entries(word_cloud.id)

      assert user_id == user.id
    end

    test "tabs sharing an attendee update their own words and remaining submissions", %{
      conn: conn,
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file, %{max_entries: 2})
      {:ok, first, _html} = live(conn, ~p"/e/#{event.code}")
      {:ok, second, _html} = live(conn, ~p"/e/#{event.code}")

      first
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
      |> render_submit()

      assert attendee_cloud(second, word_cloud) == ["Elixir"]
      assert has_element?(second, ~s(form[phx-submit="submit-word"]))
      assert render(second) =~ "You can send one more word."

      second
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Phoenix"})
      |> render_submit()

      for view <- [first, second] do
        assert attendee_cloud(view, word_cloud) == ["Elixir", "Phoenix"]
        refute has_element?(view, ~s(form[phx-submit="submit-word"]))
        assert has_element?(view, "[data-submitted]")
      end
    end

    test "a rejected submission recovers before its entry notification arrives", %{
      conn: conn,
      user: user,
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

      word_cloud_entry_fixture(%{
        word_cloud: word_cloud,
        user_id: user.id,
        attendee_identifier: nil,
        content: "Elixir"
      })

      render_hook(view, "submit-word", %{"word" => "Phoenix"})

      refute has_element?(view, ~s(form[phx-submit="submit-word"]))
      assert has_element?(view, "[data-submitted]")
      assert attendee_cloud(view, word_cloud) == ["Elixir"]
    end

    test "the cloud is left out of the markup while attendees may not see it", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file, %{show_results: false})
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Zanzibar"})

      {:ok, view, html} = live(build_conn(), ~p"/e/#{event.code}")
      refute html =~ "Zanzibar"
      refute has_element?(view, "##{word_cloud.id}-word-cloud-cloud")

      {:ok, word_cloud} =
        Claper.WordClouds.update_word_cloud(event.uuid, word_cloud, %{show_results: true})

      assert attendee_cloud(view, word_cloud) == ["Zanzibar"]
      assert has_element?(view, ~s(form[phx-submit="submit-word"]))

      {:ok, _} =
        Claper.WordClouds.update_word_cloud(event.uuid, word_cloud, %{show_results: false})

      refute has_element?(view, "##{word_cloud.id}-word-cloud-cloud")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Mine"})
        |> render_submit()

      assert html =~ "Mine"
      refute html =~ "Zanzibar"
      refute has_element?(view, "##{word_cloud.id}-word-cloud-cloud")
    end

    test "a hidden word is left out of the attendee's cloud", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      word_cloud_entry_fixture(%{word_cloud: word_cloud, content: "Grumpfwort"})
      {:ok, _} = Claper.WordClouds.hide_word(event.uuid, word_cloud, "grumpfwort")

      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Kind"})
        |> render_submit()

      assert attendee_cloud(view, word_cloud) == ["Kind"]
      refute html =~ "Grumpfwort"
    end

    test "an unsubmitted attendee sees the first word another attendee sends", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      refute has_element?(view, "##{word_cloud.id}-word-cloud-cloud")

      {:ok, _} = Claper.WordClouds.submit_entry(event.uuid, word_cloud, "someone else", "Erlang")

      assert attendee_cloud(view, word_cloud) == ["Erlang"]
      assert has_element?(view, ~s(form[phx-submit="submit-word"]))
      refute has_element?(view, "[data-submitted]")
    end

    test "an attendee can send as many words as the cloud allows", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file, %{max_entries: 2})
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "Elixir"})
        |> render_submit()

      assert html =~ "You can send one more word."

      html =
        view
        |> form(~s(form[phx-submit="submit-word"]), %{word: "ELIXIR"})
        |> render_submit()

      assert html =~ "You have already sent this word."

      view
      |> form(~s(form[phx-submit="submit-word"]), %{word: "Erlang"})
      |> render_submit()

      refute has_element?(view, ~s(form[phx-submit="submit-word"]))

      for _attempt <- 1..3 do
        assert render_hook(view, "submit-word", %{"word" => "Gleam"}) =~
                 "You have already sent your 2 words."
      end

      assert length(Claper.WordClouds.list_entries(word_cloud.id)) == 2
      assert [audit] = submission_audits_for_event("word_cloud", event.id)
      assert audit.resource_id == word_cloud.id
      assert audit.metadata["reason"] == "limit_reached"
      assert audit.metadata["observed_count"] == 3
      refute Jason.encode!(audit.metadata) =~ "Gleam"
    end

    test "a blank word is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      for _attempt <- 1..3 do
        assert render_hook(view, "submit-word", %{"word" => "   "}) =~
                 "Your word could not be added. Please type a word or a short phrase."
      end

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
      assert submission_audits_for_event("word_cloud", event.id) == []
    end

    test "a word longer than a column holds is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")
      word = "a" <> String.duplicate("\u0301", 300)

      assert render_hook(view, "submit-word", %{"word" => word}) =~
               "Your word could not be added. Please type a word or a short phrase."

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
    end

    test "a short word whose key outgrows its column is refused with a message", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      assert render_hook(view, "submit-word", %{"word" => String.duplicate("\uFDFA", 15)}) =~
               "Your word could not be added. Please type a word or a short phrase."

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
    end

    test "a word cloud that was closed meanwhile takes no words", %{
      presentation_file: presentation_file,
      event: event
    } do
      word_cloud = open_word_cloud(presentation_file)
      {:ok, view, _html} = live(build_conn(), ~p"/e/#{event.code}")

      {:ok, _} = Claper.WordClouds.set_disabled(word_cloud.id)

      for _attempt <- 1..3 do
        render_hook(view, "submit-word", %{"word" => "Elixir"})
      end

      assert Claper.WordClouds.list_entries(word_cloud.id) == []
      refute has_element?(view, ~s(form[phx-submit="submit-word"]))
      assert submission_audits_for_event("word_cloud", event.id) == []
    end
  end

  defp submission_audits_for_event(resource_type, event_id) do
    {logs, _meta} =
      Claper.Audit.list_logs(%{
        filters: [%{field: :action, op: :==, value: "security.suspicious_submission"}]
      })

    Enum.filter(logs, &(&1.resource_type == resource_type && &1.metadata["event_id"] == event_id))
  end

  defp open_word_cloud(presentation_file, attrs \\ %{}) do
    word_cloud_fixture(
      Map.merge(%{presentation_file: presentation_file, title: "One word"}, attrs)
    )
  end

  defp attendee_cloud(view, word_cloud) do
    view
    |> element("##{word_cloud.id}-word-cloud-cloud")
    |> render()
    |> word_cloud_names()
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
