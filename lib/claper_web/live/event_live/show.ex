defmodule ClaperWeb.EventLive.Show do
  alias Claper.Interactions
  use ClaperWeb, :live_view

  alias Claper.{Posts, Polls, Forms, Presentations, Quizzes, Stats, Transcriptions}
  alias ClaperWeb.Presence

  on_mount(ClaperWeb.AttendeeLiveAuth)

  @global_react_types %{
    "heart" => :heart,
    "clap" => :clap,
    "hundred" => :hundred,
    "raisehand" => :raisehand
  }

  @reaction_fields %{
    like: {:like_count, :like_posts},
    love: {:love_count, :love_posts},
    lol: {:lol_count, :lol_posts}
  }

  @post_reaction_types %{"👍" => :like, "❤️" => :love, "😂" => :lol}

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

    slide_urls = Presentations.get_slide_urls(event.presentation_file)
    current_position = event.presentation_file.presentation_state.position

    socket =
      socket
      |> assign(:attendees_nb, online_attendees(event))
      |> assign(:post_changeset, post_changeset)
      |> assign(:like_posts, reacted_posts(socket, event.id, "👍"))
      |> assign(:love_posts, reacted_posts(socket, event.id, "❤️"))
      |> assign(:lol_posts, reacted_posts(socket, event.id, "😂"))
      |> assign(:selected_poll_opt, [])
      |> assign(:selected_rating, nil)
      |> assign(:selected_quiz_question_opts, [])
      |> assign(:current_quiz_question_idx, 0)
      |> assign(:event, event)
      |> assign(:state, event.presentation_file.presentation_state)
      |> assign(:slide_urls, slide_urls)
      |> assign(:current_slide_url, Enum.at(slide_urls, current_position))
      |> assign(:transcription_text, "")
      |> assign(
        :transcription_config,
        Transcriptions.get_transcription_config(event.presentation_file.id)
      )
      |> assign(:nickname, "")
      |> stream(:posts, posts)
      |> assign(:post_count, Enum.count(posts))
      |> starting_soon_assigns(event)
      |> get_current_interaction(event, current_position)
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

  defp online_attendees(event) do
    event.uuid
    |> then(&Presence.list("event:#{&1}"))
    |> Enum.count()
    |> max(1)
  end

  defp check_leader(%{assigns: %{current_user: current_user} = _assigns} = socket, event)
       when is_map(current_user) do
    is_leader =
      current_user.id == event.user_id || Claper.Events.led_by?(current_user.email, event)

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
    position_changed = socket.assigns.state.position != presentation_state.position

    message_reactions_changed =
      socket.assigns.state.message_reaction_enabled !=
        presentation_state.message_reaction_enabled

    socket =
      socket
      |> assign(:state, presentation_state)
      |> assign_current_slide(presentation_state.position)

    socket =
      if message_reactions_changed do
        stream(socket, :posts, list_posts(socket, socket.assigns.event.uuid), reset: true)
      else
        socket
      end

    {:noreply, if(position_changed, do: refresh_current_interaction(socket), else: socket)}
  end

  @impl true
  def handle_info({:event_terminated, _event_uuid}, socket) do
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
     |> assign(:state, %{socket.assigns.state | position: page})
     |> assign_current_slide(page)
     |> get_current_interaction(socket.assigns.event, page)
     |> push_event("reset-global-react", %{})}
  end

  @impl true
  def handle_info(
        {:current_interaction, _interaction},
        socket
      ) do
    {:noreply, refresh_current_interaction(socket)}
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
  def handle_info({:poll_updated, %Claper.Polls.Poll{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:poll_deleted, %Claper.Polls.Poll{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:form_updated, %Claper.Forms.Form{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:form_deleted, %Claper.Forms.Form{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:embed_updated, %Claper.Embeds.Embed{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:embed_deleted, %Claper.Embeds.Embed{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:quiz_updated, %Claper.Quizzes.Quiz{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:quiz_deleted, %Claper.Quizzes.Quiz{}}, socket) do
    {:noreply, refresh_current_interaction(socket, true)}
  end

  @impl true
  def handle_info({:react, type}, socket) do
    {:noreply,
     socket
     |> push_event("global-react", %{type: type})}
  end

  @impl true
  def handle_info({:transcription_created, transcription}, socket) do
    {:noreply, socket |> assign(:transcription_text, transcription.text)}
  end

  @impl true
  def handle_info({:transcription_delta, text}, socket) do
    {:noreply, socket |> assign(:transcription_text, text)}
  end

  @impl true
  def handle_info({:transcription_config_updated, config}, socket) do
    {:noreply, socket |> assign(:transcription_config, config)}
  end

  @impl true
  def handle_info({:transcription_config_deleted, _config}, socket) do
    {:noreply, socket |> assign(:transcription_config, nil)}
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
  def handle_event("delete", %{"id" => id}, socket) do
    post = Posts.get_post_for_event(id, socket.assigns.event.id, [:event])

    if post && can_delete_post?(socket, post) do
      {:ok, _} = Posts.delete_post(post)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, %{assigns: %{state: %{chat_enabled: false}}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        event,
        _params,
        %{assigns: %{state: %{message_reaction_enabled: false}}} = socket
      )
      when event in ["react", "unreact"] do
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "save",
        _params,
        %{assigns: %{state: %{anonymous_chat_enabled: false}, nickname: nickname}} = socket
      )
      when nickname in [nil, ""] do
    {:noreply, socket}
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
        {:noreply,
         socket
         |> assign(:post_changeset, Posts.Post.changeset(%Posts.Post{}, %{}))
         |> push_event("post-saved", %{})}

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
        {:noreply,
         socket
         |> assign(:post_changeset, Posts.Post.changeset(%Posts.Post{}, %{}))
         |> push_event("post-saved", %{})}

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
    case {socket.assigns.state.message_reaction_enabled, Map.get(@global_react_types, type)} do
      {false, _} ->
        {:noreply, socket}

      {_, nil} ->
        {:noreply, socket}

      {true, type_atom} ->
        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{socket.assigns.event.uuid}",
          {:react, type_atom}
        )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set-nickname", %{"nickname" => nickname}, socket) do
    nickname = String.trim(nickname)

    cond do
      nickname == "" && socket.assigns.state.anonymous_chat_enabled ->
        {:noreply, assign(socket, :nickname, "")}

      nickname == "" ->
        {:noreply, socket}

      true ->
        changeset = Posts.Post.nickname_changeset(%Posts.Post{}, %{"name" => nickname})

        if changeset.valid? do
          {:noreply, assign(socket, :nickname, nickname)}
        else
          {:noreply, assign(socket, :post_changeset, %{changeset | action: :insert})}
        end
    end
  end

  @impl true
  def handle_event(
        "react",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    case Map.get(@post_reaction_types, type) do
      nil ->
        {:noreply, socket}

      reaction ->
        {:noreply,
         add_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, reaction)}
    end
  end

  @impl true
  def handle_event(
        "react",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = socket
      ) do
    case Map.get(@post_reaction_types, type) do
      nil ->
        {:noreply, socket}

      reaction ->
        {:noreply,
         add_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           reaction
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
    case Map.get(@post_reaction_types, type) do
      nil ->
        {:noreply, socket}

      reaction ->
        {:noreply,
         remove_reaction(socket, post_id, %{icon: type, user_id: current_user.id}, reaction)}
    end
  end

  @impl true
  def handle_event(
        "unreact",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{attendee_identifier: attendee_identifier} = _assigns} = socket
      ) do
    case Map.get(@post_reaction_types, type) do
      nil ->
        {:noreply, socket}

      reaction ->
        {:noreply,
         remove_reaction(
           socket,
           post_id,
           %{icon: type, attendee_identifier: attendee_identifier},
           reaction
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
  def handle_event("select-rating", %{"value" => value}, socket) do
    {:noreply, socket |> assign(:selected_rating, value)}
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

      # a vote pushed at something that takes no votes (a slider poll, an option
      # that is not on this poll): nothing to record, nothing to say
      {:error, _reason} ->
        {:noreply, socket}
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

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "submit-rating",
        %{"value" => value},
        %{assigns: %{current_user: current_user}} = socket
      )
      when is_map(current_user) do
    case Claper.Polls.submit_rating(
           current_user.id,
           socket.assigns.event.uuid,
           socket.assigns.current_interaction.id,
           value
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}

      # this view was showing a form for a rating that is already in: catch it
      # up instead of leaving the form on screen
      {:error, :already_voted} ->
        {:noreply, socket |> get_current_vote(socket.assigns.current_interaction.id)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "submit-rating",
        %{"value" => value},
        %{assigns: %{attendee_identifier: attendee_identifier}} = socket
      ) do
    case Claper.Polls.submit_rating(
           attendee_identifier,
           socket.assigns.event.uuid,
           socket.assigns.current_interaction.id,
           value
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}

      {:error, :already_voted} ->
        {:noreply, socket |> get_current_vote(socket.assigns.current_interaction.id)}

      {:error, _reason} ->
        {:noreply, socket}
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

    if Enum.any?(socket.assigns.selected_quiz_question_opts, fn x ->
         x.id == quiz_question_opt.id
       end) do
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
           current_user,
           socket.assigns.event.uuid,
           opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> load_current_interaction(quiz, true)
         |> assign(:selected_quiz_question_opts, [])
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
           socket.assigns.event.uuid,
           opts,
           socket.assigns.current_interaction.id
         ) do
      {:ok, quiz} ->
        {:noreply,
         socket
         |> load_current_interaction(quiz, true)
         |> assign(:selected_quiz_question_opts, [])
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
    with %Posts.Post{} = post <-
           Posts.get_post_for_event(post_id, socket.assigns.event.id, [:event]),
         false <- own_post?(socket, post),
         {:ok, _} <- Posts.create_reaction(Map.merge(params, %{post: post})) do
      {count_field, posts_field} = @reaction_fields[type]

      {:ok, _} = Posts.update_post(post, %{count_field => Map.get(post, count_field) + 1})
      update(socket, posts_field, fn posts -> [post.id | posts] end)
    else
      _ -> socket
    end
  end

  defp remove_reaction(socket, post_id, params, type) do
    with %Posts.Post{} = post <-
           Posts.get_post_for_event(post_id, socket.assigns.event.id, [:event]),
         {:ok, _} <- Posts.delete_reaction(Map.merge(params, %{post: post})) do
      {count_field, posts_field} = @reaction_fields[type]

      {:ok, _} = Posts.update_post(post, %{count_field => Map.get(post, count_field) - 1})
      update(socket, posts_field, fn posts -> List.delete(posts, post.id) end)
    else
      _ -> socket
    end
  end

  defp can_delete_post?(%{assigns: %{is_leader: true}}, _post), do: true

  defp can_delete_post?(%{assigns: %{current_user: %{id: user_id}}}, %{user_id: user_id}),
    do: true

  defp can_delete_post?(
         %{assigns: %{attendee_identifier: attendee_identifier}},
         %{attendee_identifier: attendee_identifier}
       ),
       do: true

  defp can_delete_post?(_socket, _post), do: false

  defp own_post?(%{assigns: %{current_user: %{id: user_id}}}, %{user_id: user_id}), do: true

  defp own_post?(
         %{assigns: %{attendee_identifier: attendee_identifier}},
         %{attendee_identifier: attendee_identifier}
       )
       when not is_nil(attendee_identifier),
       do: true

  defp own_post?(_socket, _post), do: false

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

  defp refresh_current_interaction(socket, preserve_state \\ false) do
    interaction =
      Interactions.get_active_interaction(socket.assigns.event, socket.assigns.state.position)

    same_interaction =
      preserve_state && same_interaction?(socket.assigns.current_interaction, interaction)

    socket
    |> assign(:current_interaction, interaction)
    |> load_current_interaction(interaction, same_interaction)
  end

  defp same_interaction?(%{id: current_id}, %{id: next_id}), do: current_id == next_id
  defp same_interaction?(_, _), do: false

  defp assign_current_slide(socket, position) do
    presentation_file =
      Presentations.get_presentation_file!(socket.assigns.event.presentation_file.id)

    slide_urls = Presentations.get_slide_urls(presentation_file)

    socket
    |> assign(:slide_urls, slide_urls)
    |> assign(:current_slide_url, Enum.at(slide_urls, position))
  end

  defp focus_key(%{__struct__: module, id: id}, _position), do: "#{module}:#{id}"
  defp focus_key(_, position), do: "slide:#{position}"

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

  defp load_current_interaction(socket, %Forms.Form{} = interaction, _same_interaction) do
    socket |> assign(:current_interaction, interaction) |> get_current_form_submit(interaction.id)
  end

  defp load_current_interaction(socket, %Quizzes.Quiz{} = interaction, same_interaction) do
    quiz = Quizzes.set_percentages(interaction)

    socket =
      socket
      |> assign(:current_interaction, quiz)
      |> get_current_quiz_reponses(interaction.id)

    if same_interaction do
      socket
    else
      if length(socket.assigns.current_quiz_responses) > 0 do
        socket
        |> assign(:current_quiz_question_idx, length(interaction.quiz_questions))
      else
        socket
        |> assign(:current_quiz_question_idx, 0)
        |> assign(:selected_quiz_question_opts, [])
      end
    end
  end

  defp load_current_interaction(socket, interaction, _same_interaction) do
    socket |> assign(:current_interaction, interaction)
  end

  defp maybe_reset_selected_poll_opt(socket, true) do
    socket
  end

  defp maybe_reset_selected_poll_opt(socket, _same_interaction) do
    socket |> assign(:selected_poll_opt, []) |> assign(:selected_rating, nil)
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
