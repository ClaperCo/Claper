defmodule ClaperWeb.EventLive.Show do
  alias Claper.Interactions
  use ClaperWeb, :live_view

  alias Claper.{Posts, Polls, Stories, Forms, Quizzes, Stats}
  alias ClaperWeb.Presence

  on_mount(ClaperWeb.AttendeeLiveAuth)

  @impl true
  def mount(%{"code" => code}, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    event =
      Claper.Events.get_event_with_code(code,
        presentation_file: [:presentation_state],
        user: []
      )

    if is_nil(event) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Event doesn't exist"))
       |> redirect(to: "/")}
    else
      init(
        socket,
        event,
        check_if_banned(event.presentation_file.presentation_state.banned, socket)
      )
    end
  end

  defp check_if_banned(banned, %{assigns: %{current_user: current_user} = _assigns} = _socket)
       when is_map(current_user) do
    Enum.member?(banned, "#{current_user.id}")
  end

  defp check_if_banned(
         banned,
         %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = _socket
       ) do
    Enum.member?(banned, attendee_identifier)
  end

  defp init(socket, _event, true) do
    {:ok,
     socket
     |> put_flash(:error, gettext("You have been banned from this event"))
     |> redirect(to: "/")}
  end

  defp init(socket, event, false) do
    if connected?(socket) do
      Claper.Events.Event.subscribe(event.uuid)
      Claper.Presentations.subscribe(event.presentation_file.id)

      Presence.track(
        self(),
        "event:#{event.uuid}",
        socket.assigns.attendee_identifier,
        %{}
      )

      online = Presence.list("event:#{event.uuid}") |> Enum.count()
      update_stats(socket, event)
      maybe_update_audience_peak(event, online)
    end

    post_changeset = Posts.Post.changeset(%Posts.Post{}, %{})

    posts = list_posts(socket, event.uuid)

    socket =
      socket
      |> assign(:attendees_nb, 1)
      |> assign(:post_changeset, post_changeset)
      |> assign(:like_posts, reacted_posts(socket, event.id, "👍"))
      |> assign(:love_posts, reacted_posts(socket, event.id, "❤️"))
      |> assign(:lol_posts, reacted_posts(socket, event.id, "😂"))
      |> assign(:selected_poll_opt, [])
      |> assign(:selected_story_opt, [])
      |> assign(:selected_quiz_question_opts, [])
      |> assign(:current_quiz_question_idx, 0)
      |> assign(:event, event)
      |> assign(:state, event.presentation_file.presentation_state)
      |> assign(:nickname, "")
      |> stream(:posts, posts)
      |> assign(:post_count, Enum.count(posts))
      |> starting_soon_assigns(event)
      |> get_current_interaction(event, event.presentation_file.presentation_state.position)
      |> check_leader(event)
      |> leader_list(event)

    {:ok, socket}
  end

  defp leader_list(socket, event) do
    assign(socket, :leaders, Claper.Events.get_activity_leaders_for_event(event.id))
  end

  defp maybe_update_audience_peak(event, online) do
    if online > event.audience_peak do
      Claper.Events.update_event(event, %{audience_peak: online})
    end
  end

  defp check_leader(%{assigns: %{current_user: current_user} = _assigns} = socket, event)
       when is_map(current_user) do
    is_leader =
      current_user.id == event.user_id || Claper.Events.leaded_by?(current_user.email, event)

    socket |> assign(:is_leader, is_leader)
  end

  defp check_leader(socket, _event), do: socket |> assign(:is_leader, false)

  defp starting_soon_assigns(socket, event) do
    if Claper.Events.Event.started?(event) do
      socket |> assign(:started, true)
    else
      :timer.send_interval(1000, self(), :tick)

      diff =
        DateTime.to_unix(DateTime.from_naive!(event.started_at, "Etc/UTC")) -
          DateTime.to_unix(DateTime.utc_now())

      with {days, hours, minutes, seconds} <- seconds_to_d_h_m_s(diff) do
        socket
        |> assign(:remaining_days, days)
        |> assign(:remaining_hours, hours)
        |> assign(:remaining_minutes, minutes)
        |> assign(:remaining_seconds, seconds)
        |> assign(:diff, diff)
        |> assign(:started, false)
      end
    end
  end

  defp seconds_to_d_h_m_s(seconds) do
    {div(seconds, 86_400), rem(seconds, 86_400) |> div(3600), rem(seconds, 3600) |> div(60),
     rem(seconds, 3600) |> rem(60)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{diff: 0}} = socket) do
    {:noreply,
     socket
     |> redirect(to: ~p"/e/#{String.downcase(socket.assigns.event.code)}")}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{diff: diff}} = socket) do
    with {days, hours, minutes, seconds} <- seconds_to_d_h_m_s(diff) do
      {:noreply,
       socket
       |> assign(:remaining_days, days)
       |> assign(:remaining_hours, hours)
       |> assign(:remaining_minutes, minutes)
       |> assign(:remaining_seconds, seconds)
       |> assign(:diff, diff - 1)}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, %{assigns: %{event: event}} = socket) do
    attendees = Presence.list("event:#{event.uuid}")

    {:noreply, push_event(socket, "update-attendees", %{count: Enum.count(attendees)})}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply,
     socket
     |> stream_insert(:posts, post)
     |> update(:post_count, fn count -> count + 1 end)}
  end

  @impl true
  def handle_info({:state_updated, presentation_state}, socket) do
    {:noreply,
     socket
     |> assign(:state, presentation_state)
     |> stream(:posts, list_posts(socket, socket.assigns.event.uuid), reset: true)}
  end

  @impl true
  def handle_info({:event_terminated, _event}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, gettext("This event has been terminated"))
     |> push_navigate(to: ~p"/")}
  end

  @impl true
  def handle_info(
        {:banned, user_id},
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    if user_id == current_user.id do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You have been banned from this event"))
       |> push_navigate(to: ~p"/")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        {:banned, attendee_identifier},
        %{assigns: %{attendee_identifier: current_attendee_identifier} = _assigns} = socket
      ) do
    if attendee_identifier == current_attendee_identifier do
      {:noreply,
       socket
       |> put_flash(:error, gettext("You have been banned from this event"))
       |> push_navigate(to: ~p"/")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:page_changed, page}, socket) do
    {:noreply,
     socket
     |> assign(:current_page, page)
     |> get_current_interaction(socket.assigns.event, page)
     |> push_event("reset-global-react", %{})}
  end

  @impl true
  def handle_info(
        {:current_interaction, interaction},
        socket
      ) do
    {:noreply, socket |> load_current_interaction(interaction, false)}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({:post_pinned, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({:post_unpinned, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({:reaction_added, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({:reaction_removed, post}, socket) do
    {:noreply, socket |> stream_insert(:posts, post)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply,
     socket
     |> stream_delete(:posts, post)
     |> update(:post_count, fn count -> count - 1 end)}
  end

  @impl true
  def handle_info({:poll_updated, %Claper.Polls.Poll{enabled: true} = poll}, socket) do
    {:noreply,
     socket
     |> load_current_interaction(poll, true)}
  end

  @impl true
  def handle_info({:poll_deleted, %Claper.Polls.Poll{enabled: true}}, socket) do
    {:noreply,
     socket
     |> update(:current_interaction, fn _current_interaction -> nil end)}
  end

  @impl true
  def handle_info({:story_updated, %Claper.Stories.Story{enabled: true} = story}, socket) do
    {:noreply,
     socket
     |> load_current_interaction(story, true)}
  end

  @impl true
  def handle_info({:story_deleted, %Claper.Stories.Story{enabled: true}}, socket) do
    {:noreply,
     socket
     |> update(:current_interaction, fn _current_interaction -> nil end)}
  end

  @impl true
  def handle_info({:form_updated, %Claper.Forms.Form{enabled: true} = form}, socket) do
    {:noreply,
     socket
     |> load_current_interaction(form, true)}
  end

  @impl true
  def handle_info({:form_deleted, %Claper.Forms.Form{enabled: true}}, socket) do
    {:noreply,
     socket
     |> update(:current_interaction, fn _current_interaction -> nil end)}
  end

  @impl true
  def handle_info({:embed_updated, %Claper.Embeds.Embed{enabled: true} = embed}, socket) do
    {:noreply,
     socket
     |> load_current_interaction(embed, true)}
  end

  @impl true
  def handle_info({:embed_deleted, %Claper.Embeds.Embed{enabled: true}}, socket) do
    {:noreply,
     socket
     |> update(:current_embed, fn _current_embed -> nil end)}
  end

  @impl true
  def handle_info({:quiz_updated, %Claper.Quizzes.Quiz{enabled: true} = quiz}, socket) do
    {:noreply,
     socket
     |> load_current_interaction(quiz, true)}
  end

  @impl true
  def handle_info({:quiz_deleted, %Claper.Quizzes.Quiz{enabled: true}}, socket) do
    {:noreply,
     socket
     |> update(:current_interaction, fn _current_interaction -> nil end)}
  end

  @impl true
  def handle_info({:react, type}, socket) do
    {:noreply,
     socket
     |> push_event("global-react", %{type: type})}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("delete", %{"event-id" => event_id, "id" => id}, socket) do
    post = Posts.get_post!(id, [:event])
    {:ok, _} = Posts.delete_post(post)

    {:noreply, assign(socket, :posts, list_posts(socket, event_id))}
  end

  @impl true
  def handle_event(
        "save",
        %{"post" => post_params},
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    post_params =
      post_params
      |> Map.put("user_id", current_user.id)
      |> Map.put("position", socket.assigns.state.position)
      |> Map.put("name", socket.assigns.nickname)

    case Posts.create_post(socket.assigns.event, post_params) do
      {:ok, _post} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, post_changeset: changeset)}
    end
  end

  @impl true
  def handle_event(
        "save",
        %{"post" => post_params},
        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = socket
      ) do
    post_params =
      post_params
      |> Map.put("attendee_identifier", attendee_identifier)
      |> Map.put("position", socket.assigns.state.position)
      |> Map.put("name", socket.assigns.nickname)

    case Posts.create_post(socket.assigns.event, post_params) do
      {:ok, _post} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, post_changeset: changeset)}
    end
  end

  @impl true
  def handle_event(
        "save-nickname",
        %{"post" => post_params},
        socket
      ) do
    changeset = Posts.Post.nickname_changeset(%Posts.Post{}, post_params)

    case changeset.valid? do
      true ->
        {:noreply, socket |> assign(:nickname, post_params["name"])}

      false ->
        {:noreply, assign(socket, post_changeset: %{changeset | action: :insert})}
    end
  end

  @impl true
  def handle_event(
        "global-react",
        %{"type" => type},
        socket
      ) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:react, String.to_atom(type)}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-nickname", %{"nickname" => nickname}, socket) do
    {:noreply,
     socket
     |> assign(:nickname, nickname)}
  end

  @impl true
  def handle_event(
        "react",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    case type do
      "👍" ->
        {:noreply, add_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :like)}

      "❤️" ->
        {:noreply, add_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :love)}

      "😂" ->
        {:noreply, add_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :lol)}
    end
  end

  @impl true
  def handle_event(
        "react",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = socket
      ) do
    case type do
      "👍" ->
        {:noreply,
         add_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :like
         )}

      "❤️" ->
        {:noreply,
         add_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :love
         )}

      "😂" ->
        {:noreply,
         add_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :lol
         )}
    end
  end

  @impl true
  def handle_event(
        "unreact",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    case type do
      "👍" ->
        {:noreply,
         remove_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :like)}

      "❤️" ->
        {:noreply,
         remove_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :love)}

      "😂" ->
        {:noreply,
         remove_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, :lol)}
    end
  end

  @impl true
  def handle_event(
        "unreact",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = socket
      ) do
    case type do
      "👍" ->
        {:noreply,
         remove_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :like
         )}

      "❤️" ->
        {:noreply,
         remove_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :love
         )}

      "😂" ->
        {:noreply,
         remove_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           :lol
         )}
    end
  end

  @impl true
  def handle_event(
        "select-poll-opt",
        %{"opt" => opt},
        %{assigns: %{current_interaction: %{multiple: true}}} = socket
      ) do
    if Enum.member?(socket.assigns.selected_poll_opt, opt) do
      {:noreply,
       socket
       |> assign(
         :selected_poll_opt,
         Enum.filter(socket.assigns.selected_poll_opt, fn x -> x != opt end)
       )}
    else
      {:noreply, socket |> assign(:selected_poll_opt, [opt | socket.assigns.selected_poll_opt])}
    end
  end

  @impl true
  def handle_event(
        "select-poll-opt",
        %{"opt" => opt},
        %{assigns: %{current_interaction: %{multiple: false}}} = socket
      ) do
    {:noreply, socket |> assign(:selected_poll_opt, [opt])}
  end

  @impl true
  def handle_event(
        "vote",
        _params,
        %{assigns: %{current_user: current_user, selected_poll_opt: opts}} = socket
      )
      when is_map(current_user) do
    opts = Enum.map(opts, fn opt -> Integer.parse(opt) |> elem(0) end)

    poll_opts =
      Enum.map(opts, fn opt -> Enum.at(socket.assigns.current_interaction.poll_opts, opt) end)

    case Claper.Polls.vote(
           current_user.id,
           socket.assigns.event.uuid,
           poll_opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}
    end
  end

  @impl true
  def handle_event(
        "vote",
        _params,
        %{assigns: %{attendee_identifier: attendee_identifier, selected_poll_opt: opts}} = socket
      ) do
    opts = Enum.map(opts, fn opt -> Integer.parse(opt) |> elem(0) end)

    poll_opts =
      Enum.map(opts, fn opt -> Enum.at(socket.assigns.current_interaction.poll_opts, opt) end)

    case Claper.Polls.vote(
           attendee_identifier,
           socket.assigns.event.uuid,
           poll_opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}
    end
  end

  @impl true
  def handle_event(
        "select-story-opt",
        %{"opt" => opt},
        %{assigns: %{current_interaction: %{multiple: true}}} = socket
      ) do
    if Enum.member?(socket.assigns.selected_story_opt, opt) do
      {:noreply,
       socket
       |> assign(
         :selected_story_opt,
         Enum.filter(socket.assigns.selected_story_opt, fn x -> x != opt end)
       )}
    else
      {:noreply, socket |> assign(:selected_story_opt, [opt | socket.assigns.selected_story_opt])}
    end
  end

  @impl true
  def handle_event(
        "select-story-opt",
        %{"opt" => opt},
        %{assigns: %{current_interaction: %{multiple: false}}} = socket
      ) do
    {:noreply, socket |> assign(:selected_story_opt, [opt])}
  end

  @impl true
  def handle_event(
        "svote",
        _params,
        %{assigns: %{current_user: current_user, selected_story_opt: opts}} = socket
      )
      when is_map(current_user) do
    opts = Enum.map(opts, fn opt -> Integer.parse(opt) |> elem(0) end)

    story_opts =
      Enum.map(opts, fn opt -> Enum.at(socket.assigns.current_interaction.story_opts, opt) end)

    case Claper.Stories.vote(
           current_user.id,
           socket.assigns.event.uuid,
           story_opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, story} ->
        {:noreply, socket |> get_current_svote(story.id)}
    end
  end

  @impl true
  def handle_event(
        "svote",
        _params,
        %{assigns: %{attendee_identifier: attendee_identifier, selected_story_opt: opts}} = socket
      ) do
    opts = Enum.map(opts, fn opt -> Integer.parse(opt) |> elem(0) end)

    story_opts =
      Enum.map(opts, fn opt -> Enum.at(socket.assigns.current_interaction.story_opts, opt) end)

    case Claper.Stories.vote(
           attendee_identifier,
           socket.assigns.event.uuid,
           story_opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, story} ->
        {:noreply, socket |> get_current_svote(story.id)}
    end
  end

  @impl true
  def handle_event(
        "next-question",
        _params,
        %{assigns: %{current_quiz_question_idx: current_quiz_question_idx}} = socket
      ) do
    {:noreply, socket |> assign(:current_quiz_question_idx, current_quiz_question_idx + 1)}
  end

  @impl true
  def handle_event(
        "prev-question",
        _params,
        %{assigns: %{current_quiz_question_idx: current_quiz_question_idx}} = socket
      ) do
    {:noreply, socket |> assign(:current_quiz_question_idx, current_quiz_question_idx - 1)}
  end

  @impl true
  def handle_event(
        "show-quiz-results",
        _params,
        socket
      ) do
    {:noreply, socket |> assign(:current_quiz_question_idx, 0)}
  end

  @impl true
  def handle_event(
        "select-quiz-question-opt",
        %{"opt" => opt},
        socket
      ) do
    opt = Integer.parse(opt) |> elem(0)

    current_quiz_question =
      Enum.at(
        socket.assigns.current_interaction.quiz_questions,
        socket.assigns.current_quiz_question_idx
      )

    quiz_question_opt =
      Enum.find(current_quiz_question.quiz_question_opts, fn x -> x.id == opt end)

    if Enum.member?(socket.assigns.selected_quiz_question_opts, quiz_question_opt) do
      {:noreply,
       socket
       |> assign(
         :selected_quiz_question_opts,
         Enum.filter(socket.assigns.selected_quiz_question_opts, fn x ->
           x.id != quiz_question_opt.id
         end)
       )}
    else
      {:noreply,
       socket
       |> assign(:selected_quiz_question_opts, [
         quiz_question_opt | socket.assigns.selected_quiz_question_opts
       ])}
    end
  end

  @impl true
  def handle_event(
        "submit-quiz",
        _params,
        %{assigns: %{current_user: current_user, selected_quiz_question_opts: opts}} = socket
      )
      when is_map(current_user) do
    case Claper.Quizzes.submit_quiz(
           current_user.id,
           opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> load_current_interaction(quiz, true)
         |> assign(:current_quiz_question_idx, socket.assigns.current_quiz_question_idx + 1)}
    end
  end

  @impl true
  def handle_event(
        "submit-quiz",
        _params,
        %{assigns: %{attendee_identifier: attendee_identifier, selected_quiz_question_opts: opts}} =
          socket
      ) do
    case Claper.Quizzes.submit_quiz(
           attendee_identifier,
           opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> load_current_interaction(quiz, true)
         |> assign(:current_quiz_question_idx, socket.assigns.current_quiz_question_idx + 1)}
    end
  end

  def toggle_side_menu(js \\ %JS{}) do
    js
    |> JS.toggle(
      to: "#side-menu-shadow",
      out: "animate__animated animate__fadeOut",
      in: "animate__animated animate__fadeIn"
    )
    |> JS.toggle(
      to: "#side-menu",
      out: "animate__animated animate__slideOutLeft",
      in: "animate__animated animate__slideInLeft"
    )
  end

  def toggle_nickname_popup(js \\ %JS{}) do
    js
    |> JS.toggle(
      to: "#nickname-popup",
      out: "animate__animated animate__slideOutDown",
      in: "animate__animated animate__slideInUp",
      display: "flex"
    )
  end

  defp add_reaction(socket, post_id, params, type) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.create_reaction(Map.merge(params, %{post: post})) do
      count_field = String.to_atom("#{type}_count")
      posts_field = String.to_atom("#{type}_posts")

      {:ok, _} = Posts.update_post(post, %{count_field => Map.get(post, count_field) + 1})
      update(socket, posts_field, fn posts -> [post.id | posts] end)
    end
  end

  defp remove_reaction(socket, post_id, params, type) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.delete_reaction(Map.merge(params, %{post: post})) do
      count_field = String.to_atom("#{type}_count")
      posts_field = String.to_atom("#{type}_posts")

      {:ok, _} = Posts.update_post(post, %{count_field => Map.get(post, count_field) - 1})
      update(socket, posts_field, fn posts -> List.delete(posts, post.id) end)
    end
  end

  defp list_posts(_socket, event_id) do
    Posts.list_posts(event_id, [:event, :reactions, :user])
  end

  defp get_current_vote(%{assigns: %{current_user: current_user}} = socket, poll_id)
       when is_map(current_user) do
    vote = Polls.get_poll_vote(current_user.id, poll_id)
    socket |> assign(:current_poll_vote, vote)
  end

  defp get_current_vote(%{assigns: %{attendee_identifier: attendee_identifier}} = socket, poll_id) do
    vote = Polls.get_poll_vote(attendee_identifier, poll_id)
    socket |> assign(:current_poll_vote, vote)
  end

  defp get_current_svote(%{assigns: %{current_user: current_user}} = socket, story_id)
       when is_map(current_user) do
    vote = Stories.get_story_vote(current_user.id, story_id)
    socket |> assign(:current_story_vote, vote)
  end

  defp get_current_svote(
         %{assigns: %{attendee_identifier: attendee_identifier}} = socket,
         story_id
       ) do
    vote = Stories.get_story_vote(attendee_identifier, story_id)
    socket |> assign(:current_story_vote, vote)
  end

  defp get_current_form_submit(%{assigns: %{current_user: current_user}} = socket, form_id)
       when is_map(current_user) do
    fs = Forms.get_form_submit(current_user.id, form_id)
    socket |> assign(:current_form_submit, fs)
  end

  defp get_current_form_submit(
         %{assigns: %{attendee_identifier: attendee_identifier}} = socket,
         form_id
       ) do
    fs = Forms.get_form_submit(attendee_identifier, form_id)
    socket |> assign(:current_form_submit, fs)
  end

  defp get_current_quiz_reponses(%{assigns: %{current_user: current_user}} = socket, quiz_id)
       when is_map(current_user) do
    responses = Quizzes.get_quiz_responses(current_user.id, quiz_id)

    socket
    |> assign(:current_quiz_responses, responses)
    |> assign(:quiz_score, Quizzes.calculate_user_score(current_user.id, quiz_id))
  end

  defp get_current_quiz_reponses(
         %{assigns: %{attendee_identifier: attendee_identifier}} = socket,
         quiz_id
       ) do
    responses = Quizzes.get_quiz_responses(attendee_identifier, quiz_id)

    socket
    |> assign(:current_quiz_responses, responses)
    |> assign(:quiz_score, Quizzes.calculate_user_score(attendee_identifier, quiz_id))
  end

  defp reacted_posts(
         %{assigns: %{current_user: current_user} = _assigns} = _socket,
         event_id,
         icon
       )
       when is_map(current_user) do
    Posts.reacted_posts(event_id, current_user.id, icon)
  end

  defp reacted_posts(
         %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = _socket,
         event_id,
         icon
       ) do
    Posts.reacted_posts(event_id, attendee_identifier, icon)
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "##{socket.assigns.event.code} - #{socket.assigns.event.name}")
  end

  defp get_current_interaction(socket, event, position) do
    with interaction <- Interactions.get_active_interaction(event, position) do
      socket
      |> assign(:current_interaction, interaction)
      |> load_current_interaction(interaction, false)
    end
  end

  defp load_current_interaction(socket, %Polls.Poll{} = interaction, same_interaction) do
    poll = Polls.set_percentages(interaction)

    socket
    |> assign(
      :current_interaction,
      %{poll | poll_opts: Enum.sort_by(poll.poll_opts, & &1.id, :asc)}
    )
    |> maybe_reset_selected_poll_opt(same_interaction)
    |> get_current_vote(poll.id)
  end

  defp load_current_interaction(socket, %Stories.Story{} = interaction, same_interaction) do
    story = Stories.set_percentages(interaction)

    socket
    |> assign(
      :current_interaction,
      %{story | story_opts: Enum.sort_by(story.story_opts, & &1.id, :asc)}
    )
    |> maybe_reset_selected_story_opt(same_interaction)
    |> get_current_svote(story.id)
  end

  defp load_current_interaction(socket, %Forms.Form{} = interaction, _same_interaction) do
    socket |> assign(:current_interaction, interaction) |> get_current_form_submit(interaction.id)
  end

  defp load_current_interaction(socket, %Quizzes.Quiz{} = interaction, _same_interaction) do
    quiz = Quizzes.set_percentages(interaction)

    socket =
      socket
      |> assign(:current_interaction, quiz)
      |> get_current_quiz_reponses(interaction.id)

    if length(socket.assigns.current_quiz_responses) > 0 do
      socket
      |> assign(:current_quiz_question_idx, length(interaction.quiz_questions))
    else
      socket
    end
  end

  defp load_current_interaction(socket, interaction, _same_interaction) do
    socket |> assign(:current_interaction, interaction)
  end

  defp maybe_reset_selected_poll_opt(socket, true) do
    socket
  end

  defp maybe_reset_selected_poll_opt(socket, _same_interaction) do
    socket |> assign(:selected_poll_opt, [])
  end

  defp maybe_reset_selected_story_opt(socket, true) do
    socket
  end

  defp maybe_reset_selected_story_opt(socket, _same_interaction) do
    socket |> assign(:selected_story_opt, [])
  end

  defp update_stats(%{assigns: %{current_user: current_user}}, event) when is_map(current_user) do
    Stats.create_stat(event, %{
      user_id: current_user.id
    })
  end

  defp update_stats(%{assigns: %{attendee_identifier: attendee_identifier}}, event) do
    Stats.create_stat(event, %{
      attendee_identifier: attendee_identifier
    })
  end
end
