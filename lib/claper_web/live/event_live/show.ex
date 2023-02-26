defmodule ClaperWeb.EventLive.Show do
  use ClaperWeb, :live_view

  alias Claper.{Posts, Polls, Forms}
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
       |> put_flash(:error, gettext("Presentation doesn't exist"))
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

      Presence.track(
        self(),
        "event:#{event.uuid}",
        socket.assigns.attendee_identifier,
        %{}
      )
    end

    post_changeset = Posts.Post.changeset(%Posts.Post{}, %{})

    online = Presence.list("event:#{event.uuid}") |> Enum.count()

    maybe_update_audience_peak(event, online)

    socket =
      socket
      |> assign(:attendees_nb, 1)
      |> assign(:post_changeset, post_changeset)
      |> assign(:posts, list_posts(socket, event.uuid))
      |> assign(:liked_posts, reacted_posts(socket, event.id, "👍"))
      |> assign(:loved_posts, reacted_posts(socket, event.id, "❤️"))
      |> assign(:loled_posts, reacted_posts(socket, event.id, "😂"))
      |> assign(:selected_poll_opt, nil)
      |> assign(:poll_opt_saved, false)
      |> assign(:event, event)
      |> assign(:state, event.presentation_file.presentation_state)
      |> starting_soon_assigns(event)
      |> get_current_poll(event)
      |> get_current_form(event)
      |> check_leader(event)
      |> leader_list(event)

    {:ok, socket |> assign(:empty_room, Enum.count(socket.assigns.posts) == 0),
     temporary_assigns: [posts: []]}
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
      current_user.id == event.user_id || Claper.Events.is_leaded_by(current_user.email, event)

    socket |> assign(:is_leader, is_leader)
  end

  defp check_leader(socket, _event), do: socket |> assign(:is_leader, false)

  defp starting_soon_assigns(socket, event) do
    if not Claper.Events.Event.started?(event) do
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
    else
      socket |> assign(:started, true)
    end
  end

  defp seconds_to_d_h_m_s(seconds) do
    {div(seconds, 86400), rem(seconds, 86400) |> div(3600), rem(seconds, 3600) |> div(60),
     rem(seconds, 3600) |> rem(60)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{diff: 0}} = socket) do
    {:noreply,
     socket
     |> redirect(
       to: Routes.event_show_path(socket, :show, String.downcase(socket.assigns.event.code))
     )}
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

    {:noreply, assign(socket, :attendees_nb, Enum.count(attendees))}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply,
     socket
     |> update(:posts, fn posts -> [post | posts] end)
     |> push_event("scroll", %{})
     |> maybe_disable_empty_room}
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
       |> push_redirect(to: Routes.event_join_path(socket, :index))}
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
       |> push_redirect(to: Routes.event_join_path(socket, :index))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:page_changed, page}, socket) do
    {:noreply, socket |> assign(:current_page, page) |> push_event("reset-global-react", %{})}
  end

  @impl true
  def handle_info(
        {:current_poll, poll},
        socket
      ) do
    if is_nil(poll) do
      {:noreply, socket |> assign(:current_poll, poll)}
    else
      {:noreply, socket |> assign(:current_poll, poll) |> get_current_vote(poll.id)}
    end
  end

  @impl true
  def handle_info(
        {:current_form, form},
        socket
      ) do
    if is_nil(form) do
      {:noreply, socket |> assign(:current_form, form)}
    else
      {:noreply, socket |> assign(:current_form, form) |> get_current_form_submit(form.id)}
    end
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, socket |> update(:posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:reaction_added, post}, socket) do
    {:noreply, socket |> update(:posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:reaction_removed, post}, socket) do
    {:noreply, socket |> update(:posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    {:noreply, socket |> update(:posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:poll_updated, poll}, socket) do
    {:noreply,
     socket
     |> update(:current_poll, fn _current_poll -> poll end)}
  end

  @impl true
  def handle_info({:poll_deleted, _poll}, socket) do
    {:noreply,
     socket
     |> update(:current_poll, fn _current_poll -> nil end)}
  end

  @impl true
  def handle_info({:form_updated, form}, socket) do
    {:noreply,
     socket
     |> update(:current_form, fn _current_form -> form end)}
  end

  @impl true
  def handle_info({:form_deleted, _form}, socket) do
    {:noreply,
     socket
     |> update(:current_form, fn _current_form-> nil end)}
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

    case Posts.create_post(socket.assigns.event, post_params) do
      {:ok, _post} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
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

    case Posts.create_post(socket.assigns.event, post_params) do
      {:ok, _post} ->
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
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
  def handle_event(
        "react",
        %{"type" => type, "post-id" => post_id} = _params,
        %{assigns: %{current_user: current_user} = _assigns} = socket
      )
      when is_map(current_user) do
    case type do
      "👍" -> {:noreply, add_post_like(socket, post_id, %{icon: type, user_id: current_user.id})}
      "❤️" -> {:noreply, add_post_love(socket, post_id, %{icon: type, user_id: current_user.id})}
      "😂" -> {:noreply, add_post_lol(socket, post_id, %{icon: type, user_id: current_user.id})}
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
         add_post_like(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}

      "❤️" ->
        {:noreply,
         add_post_love(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}

      "😂" ->
        {:noreply,
         add_post_lol(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}
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
        {:noreply, remove_post_like(socket, post_id, %{icon: type, user_id: current_user.id})}

      "❤️" ->
        {:noreply, remove_post_love(socket, post_id, %{icon: type, user_id: current_user.id})}

      "😂" ->
        {:noreply, remove_post_lol(socket, post_id, %{icon: type, user_id: current_user.id})}
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
         remove_post_like(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}

      "❤️" ->
        {:noreply,
         remove_post_love(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}

      "😂" ->
        {:noreply,
         remove_post_lol(socket, post_id, %{icon: type, attendee_identifier: attendee_identifier})}
    end
  end

  @impl true
  def handle_event(
        "select-poll-opt",
        %{"opt" => opt},
        socket
      ) do
    {:noreply, socket |> assign(:selected_poll_opt, opt)}
  end

  @impl true
  def handle_event(
        "vote",
        %{"opt" => idx} = _params,
        %{assigns: %{current_user: current_user}} = socket
      )
      when is_map(current_user) do
    {idx, _} = Integer.parse(idx)
    poll_opt = Enum.at(socket.assigns.current_poll.poll_opts, idx)

    case Claper.Polls.vote(
           current_user.id,
           socket.assigns.event.uuid,
           poll_opt,
           socket.assigns.current_poll.id
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}
    end
  end

  @impl true
  def handle_event(
        "vote",
        %{"opt" => idx} = _params,
        %{assigns: %{attendee_identifier: attendee_identifier}} = socket
      ) do
    {idx, _} = Integer.parse(idx)
    poll_opt = Enum.at(socket.assigns.current_poll.poll_opts, idx)

    case Claper.Polls.vote(
           attendee_identifier,
           socket.assigns.event.uuid,
           poll_opt,
           socket.assigns.current_poll.id
         ) do
      {:ok, poll} ->
        {:noreply, socket |> get_current_vote(poll.id)}
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

  defp add_post_like(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.create_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{like_count: post.like_count + 1})
      update(socket, :liked_posts, fn liked_posts -> [post.id | liked_posts] end)
    end
  end

  defp remove_post_like(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.delete_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{like_count: post.like_count - 1})
      update(socket, :liked_posts, fn liked_posts -> List.delete(liked_posts, post.id) end)
    end
  end

  defp add_post_love(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.create_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{love_count: post.love_count + 1})
      update(socket, :loved_posts, fn loved_posts -> [post.id | loved_posts] end)
    end
  end

  defp remove_post_love(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.delete_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{love_count: post.love_count - 1})
      update(socket, :loved_posts, fn loved_posts -> List.delete(loved_posts, post.id) end)
    end
  end

  defp add_post_lol(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.create_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{lol_count: post.lol_count + 1})
      update(socket, :loled_posts, fn loled_posts -> [post.id | loled_posts] end)
    end
  end

  defp remove_post_lol(socket, post_id, params) do
    with post <- Posts.get_post!(post_id, [:event]),
         {:ok, _} <- Posts.delete_reaction(Map.merge(params, %{post: post})) do
      {:ok, _} = Posts.update_post(post, %{lol_count: post.lol_count - 1})
      update(socket, :loled_posts, fn loled_posts -> List.delete(loled_posts, post.id) end)
    end
  end

  defp list_posts(_socket, event_id) do
    Posts.list_posts(event_id, [:event, :reactions, :user])
  end

  defp get_current_poll(socket, event) do
    with poll <-
           Polls.get_poll_current_position(
             event.presentation_file.id,
             event.presentation_file.presentation_state.position
           ) do
      if is_nil(poll) do
        socket |> assign(:current_poll, poll)
      else
        socket |> assign(:current_poll, poll) |> get_current_vote(poll.id)
      end
    end
  end

  defp get_current_form(socket, event) do
    with form <-
           Forms.get_form_current_position(
             event.presentation_file.id,
             event.presentation_file.presentation_state.position
           ) do
      if is_nil(form) do
        socket |> assign(:current_form, form)
      else
        socket |> assign(:current_form, form) |> get_current_form_submit(form.id)
      end
    end
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

  defp get_current_form_submit(%{assigns: %{attendee_identifier: attendee_identifier}} = socket, form_id) do
    fs = Forms.get_form_submit(attendee_identifier, form_id)
    socket |> assign(:current_form_submit, fs)
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

  defp maybe_disable_empty_room(%{assigns: %{empty_room: empty_room}} = socket) do
    if empty_room, do: assign(socket, :empty_room, false), else: socket
  end
end
