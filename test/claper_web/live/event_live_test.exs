defmodule ClaperWeb.EventLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{FormsFixtures, PollsFixtures, PresentationsFixtures, QuizzesFixtures}

  @update_attrs %{name: "some updated name"}

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    params |> Map.put(:presentation_file, presentation_file)
  end

  defp add_facilitator(index_live) do
    index_live
    |> element(~s(button[phx-click="add-leader"]))
    |> render_click()
  end

  defp mark_facilitator_for_removal(index_live, leader) do
    index_live
    |> element(~s|button[phx-click="remove-stored-leader"][phx-value-remove="#{leader.id}"]|)
    |> render_click()
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_event]

    test "lists all events", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _index_live, html} = live(conn, ~p"/events")

      assert html =~ "events"
      assert html =~ presentation_file.event.name
    end

    test "updates event in listing", %{conn: conn, presentation_file: presentation_file} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      {:ok, conn} =
        index_live
        |> form("#event-form", event: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/events")

      assert html_response(conn, 200) =~ "Updated successfully"
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders the redesigned create and edit states", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, edit_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      assert has_element?(edit_live, "#event-editor-title", "Edit event")
      assert has_element?(edit_live, "#presentation-heading", "Presentation")
      assert has_element?(edit_live, "#event-details-heading", "Event details")
      assert has_element?(edit_live, ~s(#date-picker input[type="datetime-local"]))

      assert has_element?(
               edit_live,
               ~s(#date-picker input[name="event[started_at]"][type="hidden"])
             )

      assert has_element?(edit_live, "#facilitators-section")
      assert has_element?(edit_live, "#event-danger-zone", "Delete event")
      assert has_element?(edit_live, ~s(button[form="event-form"]), "Save changes")

      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      assert has_element?(new_live, "#event-editor-title", "Create event")
      assert has_element?(new_live, "#presentation-heading", "Presentation")
      assert has_element?(new_live, ~s(label[for]), "Choose file")
      refute has_element?(new_live, "#facilitators-section")
      refute has_element?(new_live, "#event-danger-zone")
      assert has_element?(new_live, ~s(button[form="event-form"]), "Create event")
    end

    test "uses the user's locale for the native date picker", %{user: user} do
      {:ok, %{locale: "fr"} = user} =
        Claper.Accounts.update_user_preferences(user, %{locale: "fr"})

      conn = build_conn() |> log_in_user(user)
      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      assert has_element?(new_live, ~s(#date-picker input[type="datetime-local"][lang="fr"]))
    end

    test "adds and removes an unsaved facilitator", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      assert has_element?(index_live, "#facilitators-empty-state")

      index_live
      |> element(~s(button[phx-click="add-leader"]))
      |> render_click()

      refute has_element?(index_live, "#facilitators-empty-state")

      assert has_element?(
               index_live,
               ~S|#facilitators-section input[type="email"]:not([readonly])|
             )

      index_live
      |> element(~s(button[phx-click="remove-leader"]))
      |> render_click()

      assert has_element?(index_live, "#facilitators-empty-state")
    end

    test "deletes a stored facilitator when saving a replacement", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      leader = Claper.EventsFixtures.activity_leader_fixture(%{event: presentation_file.event})
      replacement_email = "replacement@example.com"

      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      mark_facilitator_for_removal(index_live, leader)
      add_facilitator(index_live)

      index_live
      |> form("#event-form",
        event: %{"leaders" => %{"1" => %{"email" => replacement_email}}}
      )
      |> render_change()

      refute has_element?(
               index_live,
               ~s|#facilitators-section div[id^="facilitator-"]:not(.hidden) input[type="email"][value="#{leader.email}"]|
             )

      index_live
      |> form("#event-form")
      |> render_submit()

      updated_event =
        Claper.Events.get_event!(presentation_file.event.uuid, [:leaders])

      assert Enum.map(updated_event.leaders, & &1.email) == [replacement_email]
    end

    test "disables save when event details are invalid", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      index_live
      |> form("#event-form", event: %{name: ""})
      |> render_change()

      assert has_element?(index_live, ~s(button[form="event-form"][disabled]))
    end

    test "keeps the upload active and disables save while a presentation is starting", %{
      conn: conn
    } do
      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      new_live
      |> form("#event-form", event: %{name: "New event"})
      |> render_change()

      upload =
        file_input(new_live, "#file-form", :presentation_file, [
          %{
            name: "slides.pdf",
            content: "%PDF-" <> String.duplicate("0", 95),
            type: "application/pdf"
          }
        ])

      assert render_upload(upload, "slides.pdf", 1) =~ "Uploading... 1%"
      assert has_element?(new_live, ~s(#file-form input[type="file"]))
      assert has_element?(new_live, ~s(button[form="event-form"][disabled]))

      assert render_upload(upload, "slides.pdf", 99) =~ "New presentation ready"
      assert has_element?(new_live, ~s|button[form="event-form"]:not([disabled])|)
    end

    test "does not create an event while a presentation upload is pending", %{conn: conn} do
      {:ok, new_live, _html} = live(conn, ~p"/events/new")
      event_count = Claper.Repo.aggregate(Claper.Events.Event, :count)

      new_live
      |> form("#event-form", event: %{name: "New event"})
      |> render_change()

      upload =
        file_input(new_live, "#file-form", :presentation_file, [
          %{name: "slides.pdf", content: "%PDF-1.4", type: "application/pdf"}
        ])

      assert {:ok, _metadata} = preflight_upload(upload)

      html =
        new_live
        |> form("#event-form", event: %{name: "New event"})
        |> render_submit()

      assert html =~ "Uploading... 0%"
      assert Claper.Repo.aggregate(Claper.Events.Event, :count) == event_count
    end

    test "deletes event in listing", %{conn: conn, presentation_file: presentation_file} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      {:ok, conn} =
        index_live
        |> element(~s{a[phx-click="delete"][phx-value-id=#{presentation_file.event.uuid}]})
        |> render_click()
        |> follow_redirect(conn, ~p"/events")

      {:ok, index_live, _html} = live(conn, ~p"/events")

      refute has_element?(index_live, "#event-#{presentation_file.event.id}")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user, :create_event]

    test "displays event", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _show_live, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}")

      assert html =~ "Be the first to ask a question or share a thought."
      assert html =~ presentation_file.event.name
    end

    test "shows a moderator reply received after the attendee connects", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      post = Claper.PostsFixtures.post_fixture(%{event: presentation_file.event})
      {:ok, show_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      {:ok, reply} =
        Claper.Posts.create_post_reply(
          presentation_file.event,
          post.uuid,
          {:user, user, nil},
          "Answered live"
        )

      assert has_element?(show_live, "#reply-#{reply.uuid}", "Answered live")
    end

    test "lets the original author reply and delete their reply", %{
      presentation_file: presentation_file
    } do
      participant = Claper.AccountsFixtures.confirmed_user_fixture()

      post =
        Claper.PostsFixtures.post_fixture(%{event: presentation_file.event, user: participant})

      conn = build_conn() |> log_in_user(participant)

      {:ok, show_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      assert has_element?(
               show_live,
               ~s(button[data-reply-trigger][aria-controls="reply-form-#{post.uuid}"][phx-click*="show"])
             )

      assert has_element?(show_live, ~s(#reply-form-#{post.uuid}.hidden[phx-submit*="hide"]))
      assert has_element?(show_live, "#reply-input-#{post.uuid}")

      assert has_element?(
               show_live,
               ~s(#reply-form-#{post.uuid} button.btn-primary[type="submit"] img[src="/images/icons/send.svg"])
             )

      assert has_element?(show_live, "#reply-form-#{post.uuid} button.btn-primary", "Reply")

      render_submit(show_live, "reply", %{
        "id" => post.uuid,
        "reply_body" => "A follow-up from the author"
      })

      [reply] = Claper.Posts.get_post!(post.uuid).replies
      assert reply.author_role == :attendee
      assert reply.user_id == participant.id
      assert has_element?(show_live, "#reply-#{reply.uuid}", "A follow-up from the author")

      show_live
      |> element(~s(#reply-#{reply.uuid} button[phx-click="delete-reply"]))
      |> render_click()

      assert Claper.Posts.get_post!(post.uuid).replies == []
      refute has_element?(show_live, "#reply-#{reply.uuid}")
    end

    test "rejects a forged reply from someone outside the conversation", %{
      presentation_file: presentation_file
    } do
      author = Claper.AccountsFixtures.confirmed_user_fixture()
      unrelated_participant = Claper.AccountsFixtures.confirmed_user_fixture()
      post = Claper.PostsFixtures.post_fixture(%{event: presentation_file.event, user: author})
      conn = build_conn() |> log_in_user(unrelated_participant)

      {:ok, show_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      refute has_element?(show_live, "#reply-form-#{post.uuid}")

      html =
        render_submit(show_live, "reply", %{
          "id" => post.uuid,
          "reply_body" => "I should not be allowed to join"
        })

      assert html =~ "You cannot reply to this message"
      assert Claper.Posts.get_post!(post.uuid).replies == []
    end

    test "ignores a forged reply while messages are disabled", %{
      presentation_file: presentation_file
    } do
      participant = Claper.AccountsFixtures.confirmed_user_fixture()

      post =
        Claper.PostsFixtures.post_fixture(%{event: presentation_file.event, user: participant})

      state =
        Claper.Repo.get_by!(Claper.Presentations.PresentationState,
          presentation_file_id: presentation_file.id
        )

      {:ok, _state} =
        Claper.Presentations.update_presentation_state(state, %{chat_enabled: false})

      conn = build_conn() |> log_in_user(participant)

      {:ok, show_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}")

      render_submit(show_live, "reply", %{
        "id" => post.uuid,
        "reply_body" => "I should not bypass disabled messages"
      })

      assert Claper.Posts.get_post!(post.uuid).replies == []
    end
  end

  describe "Manage" do
    setup [:register_and_log_in_user, :create_event]

    test "keeps interaction pagination reachable on short screens", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      for index <- 1..7 do
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          title: "Poll #{index}"
        })
      end

      {:ok, manage_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")
      document = Floki.parse_document!(html)

      interaction_pane_classes =
        document
        |> Floki.attribute("#interactions-pane", "class")
        |> List.first()
        |> String.split()

      interaction_list_classes =
        document
        |> Floki.attribute("#interaction-drag-list", "class")
        |> List.first()
        |> String.split()

      assert "lg:flex" in interaction_pane_classes
      assert "lg:min-h-0" in interaction_pane_classes
      assert "lg:overflow-hidden" in interaction_pane_classes
      assert "lg:flex-1" in interaction_list_classes
      assert "lg:overflow-y-auto" in interaction_list_classes
      assert has_element?(manage_live, ~s(#interaction-drag-list button[phx-click="next-page"]))

      manage_live
      |> element(~s(#interaction-drag-list button[phx-click="next-page"]))
      |> render_click()

      assert render(manage_live) =~ "2 / 2"
    end

    test "shows more interactions when the panel is taller", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      for index <- 1..13 do
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          title: "Poll #{index}"
        })
      end

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      assert manage_live
             |> render()
             |> Floki.parse_document!()
             |> Floki.find("[data-interaction-id]")
             |> length() == 6

      manage_live
      |> element("#interaction-drag-list")
      |> render_hook("interaction-list-resized", %{"height" => 900})

      html = render(manage_live)

      assert html
             |> Floki.parse_document!()
             |> Floki.find("[data-interaction-id]")
             |> length() == 10

      assert html =~ "1 / 2"
    end

    test "prompts to regenerate missing thumbnails and starts regeneration", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, manage_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

        assert html =~ "No thumbnails are available"
        assert html =~ "Regenerate thumbnails"

        manage_live
        |> element(~s{button[phx-click="regenerate-thumbnails"]})
        |> render_click()

        assert render(manage_live) =~ "Thumbnail regeneration started"
      end)
    end

    test "appends replies to the moderator's own post and lets the moderator delete one", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      post = Claper.PostsFixtures.post_fixture(%{event: presentation_file.event, user: user})

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      assert manage_live
             |> element(~s(input[name="reply_body"]))
             |> render() =~ "@keydown.stop"

      assert has_element?(
               manage_live,
               ~s(button[aria-label="Reply"][aria-controls="reply-form-#{post.uuid}"])
             )

      assert has_element?(
               manage_live,
               ~s(label[for="reply-input-#{post.uuid}"])
             )

      assert has_element?(
               manage_live,
               ~s(button.btn-primary[type="submit"] img[src="/images/icons/send.svg"])
             )

      assert has_element?(manage_live, "button.btn-primary[type=submit]", "Reply")

      render_submit(manage_live, "reply", %{
        "id" => post.uuid,
        "reply_body" => "Thanks for the question!"
      })

      render_submit(manage_live, "reply", %{
        "id" => post.uuid,
        "reply_body" => "Here is one more detail"
      })

      [first_reply, second_reply] = Claper.Posts.get_post!(post.uuid).replies
      assert first_reply.body == "Thanks for the question!"
      assert first_reply.author_role == :host
      assert second_reply.body == "Here is one more detail"
      assert has_element?(manage_live, "#reply-#{first_reply.uuid}", "Thanks for the question!")
      assert has_element?(manage_live, "#reply-#{second_reply.uuid}", "Here is one more detail")

      manage_live
      |> element(~s(#reply-#{first_reply.uuid} button[phx-click="delete-reply"]))
      |> render_click()

      assert Enum.map(Claper.Posts.get_post!(post.uuid).replies, & &1.uuid) == [second_reply.uuid]
      refute has_element?(manage_live, "#reply-#{first_reply.uuid}")
    end

    test "flashes an error instead of silently dropping a blank reply", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      post = Claper.PostsFixtures.post_fixture(%{event: presentation_file.event})

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      render_submit(manage_live, "reply", %{"id" => post.uuid, "reply_body" => "   "})

      assert render(manage_live) =~ "A reply cannot be empty"
      assert Claper.Posts.get_post!(post.uuid).replies == []
    end

    test "does not add a replied unpinned post to the pinned list", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      Claper.PostsFixtures.post_fixture(%{
        event: presentation_file.event,
        body: "Pinned message",
        pinned: true
      })

      post =
        Claper.PostsFixtures.post_fixture(%{
          event: presentation_file.event,
          body: "Unpinned message"
        })

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      manage_live
      |> element(~s(button[phx-value-tab="pinned_posts"]))
      |> render_click()

      render_submit(manage_live, "reply", %{
        "id" => post.uuid,
        "reply_body" => "Reply to unpinned message"
      })

      refute has_element?(manage_live, "#pinned-post-list", "Reply to unpinned message")
    end

    test "rejects a reply to a post from another event", %{
      conn: conn,
      presentation_file: presentation_file,
      user: user
    } do
      other_presentation_file = presentation_file_fixture(%{user: user}, [:event])
      other_post = Claper.PostsFixtures.post_fixture(%{event: other_presentation_file.event})

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      render_submit(manage_live, "reply", %{
        "id" => other_post.uuid,
        "reply_body" => "Reply to another event"
      })

      assert render(manage_live) =~ "Resource not found"
      assert Claper.Posts.get_post!(other_post.uuid).replies == []
    end

    test "reveals quiz answers with their own toggle", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      quiz = quiz_fixture(%{presentation_file: presentation_file, position: 0, enabled: true})

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      reveal = ~s(aside button[role="switch"][phx-value-key="quiz_reveal_answers"])
      next = ~s(aside button[phx-value-key="next_quiz_question"])

      assert has_element?(manage_live, ~s(#{reveal}[phx-key="X"]))
      refute has_element?(manage_live, ~s(#{reveal}[aria-checked]))
      assert has_element?(manage_live, ~s(aside kbd), "X")
      assert has_element?(manage_live, "#{next}[disabled]")

      manage_live |> element(reveal) |> render_click()

      quiz = Claper.Quizzes.get_quiz!(quiz.id)
      assert quiz.reveal_answers
      refute quiz.show_results
      assert has_element?(manage_live, ~s(#{reveal}[aria-checked]))
      assert has_element?(manage_live, "aside", "Hide correct answers")
      refute has_element?(manage_live, "#{next}[disabled]")

      manage_live |> element(reveal) |> render_click()

      refute Claper.Quizzes.get_quiz!(quiz.id).reveal_answers
    end
  end

  describe "Presenter" do
    setup [:register_and_log_in_user]

    test "renders only the reply count on the projected display", %{conn: conn, user: user} do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file, chat_visible: true})

      post = Claper.PostsFixtures.post_fixture(%{event: presentation_file.event})

      {:ok, presenter_live, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/presenter")

      actor = {:user, user, nil}

      {:ok, _first_reply} =
        Claper.Posts.create_post_reply(
          presentation_file.event,
          post.uuid,
          actor,
          "First answer"
        )

      refute render(presenter_live) =~ "First answer"
      assert render(presenter_live) =~ "1 reply"

      {:ok, _latest_reply} =
        Claper.Posts.create_post_reply(
          presentation_file.event,
          post.uuid,
          actor,
          "Answered during the break"
        )

      refute render(presenter_live) =~ "First answer"
      refute render(presenter_live) =~ "Answered during the break"
      assert render(presenter_live) =~ "2 replies"
    end

    defp project_quiz(conn, user, attrs) do
      presentation_file = presentation_file_fixture(%{user: user}, [:event])
      presentation_state_fixture(%{presentation_file: presentation_file})
      event = presentation_file.event

      quiz =
        quiz_fixture(
          Map.merge(%{presentation_file: presentation_file, position: 0, enabled: true}, attrs)
        )

      wrong_opt = quiz.quiz_questions |> hd() |> Map.get(:quiz_question_opts) |> List.last()
      {:ok, _} = Claper.Quizzes.submit_quiz("attendee", event.uuid, [wrong_opt], quiz.id)

      {:ok, presenter_live, _html} = live(conn, ~p"/e/#{event.code}/presenter")

      {presenter_live, event, quiz}
    end

    defp toggle_quiz(event, quiz, attrs) do
      [quiz] = Claper.Quizzes.list_quizzes_at_position(quiz.presentation_file_id, quiz.position)
      {:ok, _} = Claper.Quizzes.update_quiz(event.uuid, quiz, attrs)
    end

    defp send_quiz_command(event, command) do
      Phoenix.PubSub.broadcast(Claper.PubSub, "event:#{event.uuid}", {command})
    end

    defp quiz_overlay_classes(html, quiz) do
      html
      |> Floki.parse_document!()
      |> Floki.attribute(~s([id="#{quiz.id}-quiz"]), "class")
      |> List.first()
      |> String.split()
    end

    test "projects the distribution on neutral bars until the answers are revealed", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, quiz} = project_quiz(conn, user, %{show_results: true})

      send_quiz_command(event, :review_quiz_questions)
      html = render(presenter_live)

      assert "opacity-100" in quiz_overlay_classes(html, quiz)
      assert html =~ "some question content"
      assert html =~ "100% (1)"
      refute html =~ "bg-green-600"

      toggle_quiz(event, quiz, %{reveal_answers: true})
      html = render(presenter_live)

      assert html =~ "some question content"
      assert html =~ "100% (1)"
      assert html =~ "bg-green-600"
    end

    test "projects revealed answers without the distribution", %{conn: conn, user: user} do
      {presenter_live, event, quiz} = project_quiz(conn, user, %{reveal_answers: true})

      send_quiz_command(event, :review_quiz_questions)
      html = render(presenter_live)

      assert "opacity-100" in quiz_overlay_classes(html, quiz)
      assert html =~ "bg-green-600"
      refute html =~ "100% (1)"

      toggle_quiz(event, quiz, %{reveal_answers: false})

      assert "opacity-0" in quiz_overlay_classes(render(presenter_live), quiz)
    end

    test "shows the average score on the quiz summary only once answers are revealed", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, quiz} = project_quiz(conn, user, %{show_results: true})

      html = render(presenter_live)
      assert html =~ "Total submissions"
      refute html =~ "Average score"

      toggle_quiz(event, quiz, %{reveal_answers: true})

      assert render(presenter_live) =~ "Average score"
    end

    test "starts at the first question when moving on from the quiz summary", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, _quiz} = project_quiz(conn, user, %{show_results: true})

      refute render(presenter_live) =~ "some question content"

      send_quiz_command(event, :next_quiz_question)

      assert render(presenter_live) =~ "some question content"
    end

    defp quiz_questions(contents) do
      for content <- contents do
        %{
          content: content,
          type: "qcm",
          quiz_question_opts: [
            %{content: "#{content} right", is_correct: true},
            %{content: "#{content} wrong", is_correct: false}
          ]
        }
      end
    end

    defp walk_to_second_question(conn, user) do
      {presenter_live, event, quiz} =
        project_quiz(conn, user, %{
          show_results: true,
          quiz_questions: quiz_questions(["First of A", "Second of A"])
        })

      send_quiz_command(event, :review_quiz_questions)
      send_quiz_command(event, :next_quiz_question)
      assert render(presenter_live) =~ "Second of A"

      {presenter_live, event, quiz}
    end

    test "opens another quiz on its summary when it becomes the current interaction", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, quiz} = walk_to_second_question(conn, user)

      other =
        quiz_fixture(%{
          presentation_file_id: quiz.presentation_file_id,
          position: 1,
          enabled: true,
          show_results: true,
          quiz_questions: quiz_questions(["First of B", "Second of B"])
        })

      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{event.uuid}",
        {:current_interaction, other}
      )

      html = render(presenter_live)

      assert html =~ "Total submissions"
      refute html =~ "Second of B"
    end

    test "falls back to the summary when another quiz is edited during a walkthrough", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, quiz} = walk_to_second_question(conn, user)

      other =
        quiz_fixture(%{
          presentation_file_id: quiz.presentation_file_id,
          position: 1,
          quiz_questions: quiz_questions(["Only of B"])
        })

      {:ok, _} = Claper.Quizzes.update_quiz(event.uuid, other, %{title: "Edited quiz"})

      assert render(presenter_live) =~ "Total submissions"
    end

    test "falls back to the summary when the question on screen is removed", %{
      conn: conn,
      user: user
    } do
      {presenter_live, event, quiz} = walk_to_second_question(conn, user)

      [first | _] = quiz.quiz_questions

      {:ok, _} =
        Claper.Quizzes.update_quiz(event.uuid, quiz, %{quiz_questions: [%{id: first.id}]})

      html = render(presenter_live)
      assert html =~ "Total submissions"
      refute html =~ "Second of A"
    end
  end

  describe "Stats" do
    setup [:register_and_log_in_user, :create_event]

    test "hides interaction tabs that have no content", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, _stats_live, html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      refute html =~ ~s(phx-value-tab="messages")
      refute html =~ ~s(phx-value-tab="polls")
      refute html =~ ~s(phx-value-tab="forms")
      refute html =~ ~s(phx-value-tab="web_content")
      refute html =~ ~s(phx-value-tab="quizzes")
      refute html =~ ~s(phx-value-tab="transcriptions")
    end

    test "displays transcriptions in report", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _transcription} =
        Claper.Transcriptions.create_transcription(%{
          presentation_file_id: presentation_file.id,
          language: "en",
          text: "Welcome to the event"
        })

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="transcriptions"]})
        |> render_click()

      assert html =~ "Transcriptions"
      assert html =~ "Welcome to the event"
      assert html =~ "UTC"
    end

    test "loads more transcriptions in report", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      for index <- 1..26 do
        {:ok, _transcription} =
          Claper.Transcriptions.create_transcription(%{
            presentation_file_id: presentation_file.id,
            language: "en",
            text: "Transcript segment #{index}"
          })
      end

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="transcriptions"]})
        |> render_click()

      assert html =~ "Transcriptions"
      assert html =~ "Transcript segment 1"
      refute html =~ "Transcript segment 26"
      assert html =~ "Load more"

      html =
        stats_live
        |> element(~s{button[phx-click="load_more_transcriptions"]})
        |> render_click()

      assert html =~ "Transcript segment 1"
      assert html =~ "Transcript segment 26"
      refute html =~ "Load more"
    end

    test "displays emoji avatars for form submissions in report", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      form = form_fixture(%{presentation_file_id: presentation_file.id})

      {:ok, _form_submit} =
        Claper.Forms.create_form_submit(%{
          form_id: form.id,
          attendee_identifier: "attendee-1",
          response: %{"Name" => "Ada"}
        })

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="forms"]})
        |> render_click()

      assert html =~ "Ada"
      assert html =~ "avatar avatar-placeholder"
    end
  end

  describe "Join" do
    test "renders the join page", %{conn: conn} do
      {:ok, join_live, html} = live(conn, ~p"/")

      assert html =~ "Join the event"
      assert html =~ "Enter the code shared by the presenter"
      assert html =~ "Are you a presenter?"
      assert html =~ "Start creating for free"
      refute html =~ "Turn your slides into conversations"

      assert has_element?(join_live, "#form")
      assert has_element?(join_live, "#input[placeholder='ABCD1234']")
    end
  end
end
