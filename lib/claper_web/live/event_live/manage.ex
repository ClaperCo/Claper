defmodule ClaperWeb.EventLive.Manage do
  use ClaperWeb, :live_view

  alias ClaperWeb.Presence
  alias Claper.Polls
  alias Claper.Forms
  alias Claper.Embeds
  # Add this line
  alias Claper.Quizzes
  alias Claper.Stories

  @impl true
  def mount(%{"code" => code}, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    event =
      Claper.Events.get_event_with_code(code, [
        :user,
        :lti_resource,
        presentation_file: [:polls, :presentation_state]
      ])

    if is_nil(event) || not leader?(socket, event) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Event doesn't exist"))
       |> redirect(to: "/")}
    else
      if connected?(socket) do
        Claper.Events.Event.subscribe(event.uuid)
        Claper.Presentations.subscribe(event.presentation_file.id)
      end

      posts = list_all_posts(socket, event.uuid)
      pinned_posts = list_pinned_posts(socket, event.uuid)
      questions = list_all_questions(socket, event.uuid)
      form_submits = list_form_submits(socket, event.presentation_file.id)

      socket =
        socket
        |> assign(:settings_modal, false)
        |> assign(:attendees_nb, 1)
        |> assign(:event, event)
        |> assign(:sort_questions_by, "date")
        |> assign(:state, event.presentation_file.presentation_state)
        |> stream(:posts, posts)
        |> stream(:questions, questions)
        |> stream(:pinned_posts, pinned_posts)
        |> stream(:form_submits, form_submits)
        |> assign(:pinned_post_count, length(pinned_posts))
        |> assign(:question_count, length(questions))
        |> assign(:post_count, length(posts))
        |> assign(
          :total_interactions,
          Claper.Interactions.get_number_total_interactions(event.presentation_file.id)
        )
        |> assign(
          :form_submit_count,
          length(form_submits)
        )
        |> assign(:create, nil)
        |> assign(:list_tab, :posts)
        |> assign(:create_action, :new)
        |> assign(:preview, false)
        |> push_event("page-manage", %{
          current_page: event.presentation_file.presentation_state.position,
          timeout: 500
        })
        |> interactions_at_position(event.presentation_file.presentation_state.position)

      {:ok, socket}
    end
  end

  defp leader?(%{assigns: %{current_user: current_user}} = _socket, event) do
    Claper.Events.leaded_by?(current_user.email, event) || event.user.id == current_user.id
  end

  defp leader?(_socket, _event), do: false

  @impl true
  def handle_info(%{event: "presence_diff"}, %{assigns: %{event: event}} = socket) do
    attendees = Presence.list("event:#{event.uuid}")
    {:noreply, push_event(socket, "update-attendees", %{count: Enum.count(attendees)})}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    socket =
      socket
      |> stream_insert(:posts, post)
      |> update(:post_count, fn post_count -> post_count + 1 end)

    case ClaperWeb.Helpers.body_without_links(post.body) =~ "?" do
      true ->
        {:noreply,
         socket
         |> stream_insert(:questions, post)
         |> update(:question_count, fn question_count -> question_count + 1 end)
         |> push_event("scroll", %{})}

      _ ->
        {:noreply, socket |> push_event("scroll", %{})}
    end
  end

  @impl true
  def handle_info({:post_updated, updated_post}, socket) do
    {:noreply,
     socket
     |> stream_insert(:posts, updated_post)
     |> then(fn socket ->
       sorted_questions =
         list_all_questions(socket, socket.assigns.event.uuid, socket.assigns.sort_questions_by)

       stream(socket, :questions, sorted_questions, reset: true)
     end)
     |> stream_insert(:pinned_posts, updated_post)}
  end

  @impl true
  def handle_info({:post_deleted, deleted_post}, socket) do
    socket =
      socket
      |> stream_delete(:posts, deleted_post)
      |> stream_delete(:pinned_posts, deleted_post)
      |> update(:pinned_post_count, fn pinned_post_count ->
        pinned_post_count - if deleted_post.pinned, do: 1, else: 0
      end)
      |> update(:post_count, fn post_count -> post_count - 1 end)

    case ClaperWeb.Helpers.body_without_links(deleted_post.body) =~ "?" do
      true ->
        {:noreply,
         socket
         |> stream_delete(:questions, deleted_post)
         |> update(:question_count, fn question_count -> question_count - 1 end)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:post_pinned, post}, socket) do
    updated_socket =
      socket
      |> stream_insert(:posts, post)
      |> stream_insert(:pinned_posts, post)
      |> stream_insert(:questions, post)
      |> assign(:pinned_post_count, socket.assigns.pinned_post_count + 1)

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info({:post_unpinned, post}, socket) do
    updated_socket =
      socket
      |> stream_insert(:posts, post)
      |> stream_delete(:pinned_posts, post)
      |> stream_insert(:questions, post)
      |> assign(:pinned_post_count, socket.assigns.pinned_post_count - 1)

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info({:form_submit_created, fs}, socket) do
    {:noreply,
     socket
     |> stream_insert(:form_submits, fs)
     |> update(:form_submit_count, fn form_submit_count -> form_submit_count + 1 end)
     |> push_event("scroll", %{})}
  end

  @impl true
  def handle_info({:form_submit_updated, fs}, socket) do
    {:noreply, socket |> stream_insert(:form_submits, fs)}
  end

  @impl true
  def handle_info({:form_submit_deleted, fs}, socket) do
    {:noreply,
     socket
     |> stream_delete(:form_submits, fs)
     |> update(:form_submit_count, fn form_submit_count -> form_submit_count - 1 end)}
  end

  @impl true
  def handle_info({:poll_created, poll}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(poll.position)}
  end

  @impl true
  def handle_info({:story_created, story}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(story.position)}
  end

  @impl true
  def handle_info({:form_created, form}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(form.position)}
  end

  @impl true
  def handle_info({:embed_created, embed}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(embed.position)}
  end

  @impl true
  def handle_info({:quiz_created, quiz}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(quiz.position)}
  end

  @impl true
  def handle_info({:poll_updated, poll}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(poll.position)}
  end

  @impl true
  def handle_info({:story_updated, story}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(story.position)}
  end

  @impl true
  def handle_info({:embed_updated, embed}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(embed.position)}
  end

  @impl true
  def handle_info({:form_updated, form}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(form.position)}
  end

  @impl true
  def handle_info({:quiz_updated, quiz}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(quiz.position)}
  end

  @impl true
  def handle_info({:poll_deleted, poll}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(poll.position)}
  end

  @impl true
  def handle_info({:story_deleted, story}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(story.position)}
  end

  @impl true
  def handle_info({:embed_deleted, embed}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(embed.position)}
  end

  @impl true
  def handle_info({:form_deleted, form}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(form.position)}
  end

  @impl true
  def handle_info({:quiz_deleted, quiz}, socket) do
    {:noreply,
     socket
     |> interactions_at_position(quiz.position)}
  end

  @impl true
  def handle_info(
        {:current_interaction, interaction},
        socket
      ) do
    if socket.assigns.current_interaction != interaction do
      position = if interaction, do: interaction.position, else: socket.assigns.state.position

      {:noreply,
       socket
       |> assign(:current_interaction, interaction)
       |> interactions_at_position(position)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    if state.position != socket.assigns.state.position do
      {:noreply, socket |> assign(:state, state) |> interactions_at_position(state.position)}
    else
      {:noreply, socket |> assign(:state, state)}
    end
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "current-page",
        %{"page" => page},
        %{assigns: %{state: state}} = socket
      ) do
    page = String.to_integer(page)

    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :position => page
        }
      )

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:page_changed, page}
    )

    {:noreply,
     socket
     |> assign(:state, new_state)
     |> interactions_at_position(page)}
  end

  def handle_event("poll-set-active", %{"id" => id}, socket) do
    with poll <- Polls.get_poll!(id), :ok <- Claper.Interactions.enable_interaction(poll) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, poll}
      )

      {:noreply,
       socket
       |> assign(:current_interaction, poll)
       |> interactions_at_position(socket.assigns.state.position)}
    end
  end

  def handle_event("story-set-active", %{"id" => id}, socket) do
    with story <- Stories.get_story!(id), :ok <- Claper.Interactions.enable_interaction(story) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, story}
      )

      {:noreply,
       socket
       |> assign(:current_interaction, story)
       |> interactions_at_position(socket.assigns.state.position)}
    end
  end

  def handle_event("form-set-active", %{"id" => id}, socket) do
    with form <- Forms.get_form!(id), :ok <- Claper.Interactions.enable_interaction(form) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, form}
      )

      {:noreply,
       socket
       |> assign(:current_interaction, form)
       |> interactions_at_position(socket.assigns.state.position)}
    end
  end

  def handle_event("embed-set-active", %{"id" => id}, socket) do
    with embed <- Embeds.get_embed!(id), :ok <- Claper.Interactions.enable_interaction(embed) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, embed}
      )

      {:noreply,
       socket
       |> assign(:current_interaction, embed)
       |> interactions_at_position(socket.assigns.state.position)}
    end
  end

  def handle_event("poll-set-inactive", %{"id" => id}, socket) do
    with poll <- Polls.get_poll!(id), {:ok, _} <- Claper.Interactions.disable_interaction(poll) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, nil}
      )
    end

    {:noreply,
     socket
     |> assign(:current_interaction, nil)
     |> interactions_at_position(socket.assigns.state.position)}
  end

  def handle_event("story-set-inactive", %{"id" => id}, socket) do
    with story <- Stories.get_story!(id),
         {:ok, _} <- Claper.Interactions.disable_interaction(story) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, nil}
      )
    end

    {:noreply,
     socket
     |> assign(:current_interaction, nil)
     |> interactions_at_position(socket.assigns.state.position)}
  end

  def handle_event("form-set-inactive", %{"id" => id}, socket) do
    with form <- Forms.get_form!(id), {:ok, _} <- Claper.Interactions.disable_interaction(form) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, nil}
      )
    end

    {:noreply,
     socket
     |> assign(:current_interaction, nil)
     |> interactions_at_position(socket.assigns.state.position)}
  end

  def handle_event("embed-set-inactive", %{"id" => id}, socket) do
    with embed <- Embeds.get_embed!(id),
         {:ok, _} <- Claper.Interactions.disable_interaction(embed) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, nil}
      )
    end

    {:noreply,
     socket
     |> assign(:current_interaction, nil)
     |> interactions_at_position(socket.assigns.state.position)}
  end

  @impl true
  def handle_event("quiz-set-active", %{"id" => id}, socket) do
    with quiz <- Quizzes.get_quiz!(id, [:quiz_questions, quiz_questions: :quiz_question_opts]),
         :ok <- Claper.Interactions.enable_interaction(quiz) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, quiz}
      )

      {:noreply,
       socket
       |> assign(:current_interaction, quiz)
       |> interactions_at_position(socket.assigns.state.position)}
    end
  end

  def handle_event("quiz-set-inactive", %{"id" => id}, socket) do
    with quiz <- Quizzes.get_quiz!(id),
         {:ok, _} <- Claper.Interactions.disable_interaction(quiz) do
      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "event:#{socket.assigns.event.uuid}",
        {:current_interaction, nil}
      )
    end

    {:noreply,
     socket
     |> assign(:current_interaction, nil)
     |> interactions_at_position(socket.assigns.state.position)}
  end

  @impl true
  def handle_event(
        "ban",
        %{"attendee-identifier" => attendee_identifier},
        %{assigns: %{event: event}} = socket
      ) do
    Claper.Posts.delete_all_posts(:attendee_identifier, attendee_identifier, event)

    ban(attendee_identifier, socket)
  end

  @impl true
  def handle_event("pin", %{"id" => id}, socket) do
    post = Claper.Posts.get_post!(id, [:event])
    pin(post, socket)
  end

  @impl true
  def handle_event(
        "ban",
        %{"user-id" => user_id},
        %{assigns: %{event: event}} = socket
      ) do
    Claper.Posts.delete_all_posts(:user_id, user_id, event)

    ban(String.to_integer(user_id), socket)
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "chat_visible", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :chat_visible => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "poll_visible", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :poll_visible => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "story_visible", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :story_visible => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "chat_enabled", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :chat_enabled => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "anonymous_chat_enabled", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :anonymous_chat_enabled => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "message_reaction_enabled", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :message_reaction_enabled => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "show_only_pinned", "value" => value},
        %{assigns: %{event: _event, state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :show_only_pinned => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "join_screen_visible", "value" => value},
        %{assigns: %{state: state}} = socket
      ) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(
        state,
        %{
          :join_screen_visible => value
        }
      )

    {:noreply, socket |> assign(:state, new_state)}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "quiz_show_results", "value" => value},
        %{assigns: %{current_interaction: interaction}} = socket
      ) do
    {:ok, new_interaction} =
      Claper.Quizzes.update_quiz(
        socket.assigns.event.uuid,
        interaction,
        %{
          :show_results => value
        }
      )

    {:noreply, socket |> assign(:current_interaction, new_interaction)}
  end

  @impl true
  def handle_event("checked", %{"key" => "review_quiz_questions"}, socket) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:review_quiz_questions}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("checked", %{"key" => "next_quiz_question"}, socket) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:next_quiz_question}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("checked", %{"key" => "prev_quiz_question"}, socket) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:prev_quiz_question}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    post = Claper.Posts.get_post!(id, [:event])
    {:ok, _} = Claper.Posts.delete_post(post)

    updated_socket =
      if post.pinned do
        stream(socket, :pinned_posts, list_pinned_posts(socket, socket.assigns.event.uuid),
          reset: true
        )

        stream(socket, :posts, list_all_posts(socket, socket.assigns.event.uuid), reset: true)
      else
        stream(socket, :posts, list_all_posts(socket, socket.assigns.event.uuid), reset: true)
      end

    {:noreply, updated_socket}
  end

  @impl true
  def handle_event("sort-questions", %{"sort" => sort}, socket) do
    {:noreply,
     socket
     |> assign(:sort_questions_by, sort)
     |> stream(:questions, list_all_questions(socket, socket.assigns.event.uuid, sort),
       reset: true
     )}
  end

  @impl true
  def handle_event("delete-form-submit", %{"event-id" => event_id, "id" => id}, socket) do
    form = Claper.Forms.get_form_submit_by_id!(id)
    {:ok, _} = Claper.Forms.delete_form_submit(event_id, form)

    {:noreply,
     assign(
       socket,
       :form_submits,
       list_form_submits(socket, socket.assigns.event.presentation_file.id)
     )}
  end

  @impl true
  def handle_event("list-tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :list_tab, String.to_atom(tab))

    socket =
      case tab do
        "posts" ->
          socket
          |> stream(:posts, list_all_posts(socket, socket.assigns.event.uuid), reset: true)

        "questions" ->
          socket
          |> stream(:questions, list_all_questions(socket, socket.assigns.event.uuid),
            reset: true
          )

        "forms" ->
          stream(
            socket,
            :form_submits,
            list_form_submits(socket, socket.assigns.event.presentation_file.id),
            reset: true
          )

        "pinned_posts" ->
          socket
          |> stream(:pinned_posts, list_pinned_posts(socket, socket.assigns.event.uuid),
            reset: true
          )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("maybe-redirect", _params, socket) do
    if socket.assigns.create != nil do
      {:noreply,
       socket
       |> push_navigate(to: ~p"/e/#{socket.assigns.event.code}/manage")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-poll", %{"id" => id}, socket) do
    poll = Polls.get_poll!(id)
    {:ok, _} = Polls.delete_poll(socket.assigns.event.uuid, poll)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete-story", %{"id" => id}, socket) do
    story = Stories.get_story!(id)
    {:ok, _} = Stories.delete_story(socket.assigns.event.uuid, story)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete-quiz", %{"id" => id}, socket) do
    quiz = Quizzes.get_quiz!(id)
    {:ok, _} = Quizzes.delete_quiz(socket.assigns.event.uuid, quiz)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle-preview", _params, %{assigns: %{preview: preview}} = socket) do
    {:noreply, socket |> assign(:preview, !preview)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  def toggle_add_modal(js \\ %JS{}) do
    js
    |> JS.toggle(
      to: "#add-modal",
      out: "animate__animated animate__fadeOut",
      in: "animate__animated animate__fadeIn"
    )
    |> JS.push("maybe-redirect", target: "#add-modal")
  end

  def toggle_settings_modal(js \\ %JS{}) do
    js
    |> JS.toggle(
      to: "#settings-modal",
      out: "animate__animated animate__fadeOut",
      in: "animate__animated animate__fadeIn"
    )
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp apply_action(socket, :add_poll, _params) do
    socket
    |> assign(:create, "poll")
    |> assign(:poll, %Polls.Poll{
      poll_opts: [%Polls.PollOpt{content: gettext("Yes")}, %Polls.PollOpt{content: gettext("No")}]
    })
  end

  defp apply_action(socket, :edit_poll, %{"id" => id}) do
    poll = Polls.get_poll!(id)

    socket
    |> assign(:create, "poll")
    |> assign(:create_action, :edit)
    |> assign(:poll, poll)
  end

  defp apply_action(socket, :add_story, _params) do
    socket
    |> assign(:create, "story")
    |> assign(:story, %Stories.Story{
      story_opts: [
        %Stories.StoryOpt{content: gettext("Yes")},
        %Stories.StoryOpt{content: gettext("No")}
      ]
    })
  end

  defp apply_action(socket, :edit_story, %{"id" => id}) do
    story = Stories.get_story!(id)

    socket
    |> assign(:create, "story")
    |> assign(:create_action, :edit)
    |> assign(:story, story)
  end

  defp apply_action(socket, :add_form, _params) do
    socket
    |> assign(:create, "form")
    |> assign(:form, %Forms.Form{
      fields: [
        %Forms.Field{name: gettext("Name"), type: "text"},
        %Forms.Field{name: gettext("Email"), type: "email"}
      ]
    })
  end

  defp apply_action(socket, :add_embed, _params) do
    socket
    |> assign(:create, "embed")
    |> assign(:embed, %Embeds.Embed{})
  end

  defp apply_action(socket, :import, _params) do
    socket
    |> assign(:create, "import")
    |> assign(:events, Claper.Events.list_events(socket.assigns.current_user.id))
  end

  defp apply_action(socket, :edit_form, %{"id" => id}) do
    form = Forms.get_form!(id)

    socket
    |> assign(:create, "form")
    |> assign(:create_action, :edit)
    |> assign(:form, form)
  end

  defp apply_action(socket, :edit_embed, %{"id" => id}) do
    embed = Embeds.get_embed!(id)

    socket
    |> assign(:create, "embed")
    |> assign(:create_action, :edit)
    |> assign(:embed, embed)
  end

  defp apply_action(socket, :add_quiz, _params) do
    socket
    |> assign(:create, "quiz")
    |> assign(:quiz, %Quizzes.Quiz{
      presentation_file_id: socket.assigns.event.presentation_file.id,
      quiz_questions: [
        %Quizzes.QuizQuestion{
          id: 0,
          quiz_question_opts: [
            %Quizzes.QuizQuestionOpt{
              id: 0
            },
            %Quizzes.QuizQuestionOpt{
              id: 1
            }
          ]
        }
      ]
    })
  end

  defp apply_action(socket, :edit_quiz, %{"id" => id}) do
    quiz = Quizzes.get_quiz!(id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    socket
    |> assign(:create, "quiz")
    |> assign(:create_action, :edit)
    |> assign(:quiz, quiz)
  end

  defp pin(post, socket) do
    {:ok, _updated_post} = Claper.Posts.toggle_pin_post(post)

    {:noreply, socket}
  end

  defp ban(user, %{assigns: %{event: event, state: state}} = socket) do
    {:ok, new_state} =
      Claper.Presentations.update_presentation_state(state, %{
        "banned" => state.banned ++ ["#{user}"]
      })

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event.uuid}",
      {:banned, user}
    )

    {:noreply, socket |> assign(:state, new_state)}
  end

  defp interactions_at_position(
         %{assigns: %{event: event}} = socket,
         position,
         broadcast \\ false
       ) do
    with {:ok, interactions} <-
           Claper.Interactions.get_interactions_at_position(event, position, broadcast) do
      active = interactions |> Enum.find(& &1.enabled)
      socket |> assign(:interactions, interactions) |> assign(:current_interaction, active)
    end
  end

  defp list_pinned_posts(_socket, event_id) do
    Claper.Posts.list_pinned_posts(event_id, [:event, :reactions])
  end

  defp list_all_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end

  defp list_all_questions(_socket, event_id, sort \\ "date") do
    Claper.Posts.list_questions(event_id, [:event, :reactions], String.to_atom(sort))
    |> Enum.filter(&(ClaperWeb.Helpers.body_without_links(&1.body) =~ "?"))
  end

  defp list_form_submits(_socket, presentation_file_id) do
    Claper.Forms.list_form_submits(presentation_file_id, [:form])
  end
end
