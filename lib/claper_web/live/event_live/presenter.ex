defmodule ClaperWeb.EventLive.Presenter do
  use ClaperWeb, :live_view

  alias ClaperWeb.Presence

  @impl true
  def mount(%{"code" => code}, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    event =
      Claper.Events.get_event_with_code(code, [
        :user,
        presentation_file: [:polls, :presentation_state]
      ])

    if is_nil(event) || not is_leader(socket, event) do
      {:ok,
       socket
       |> put_flash(:error, gettext("Event doesn't exist"))
       |> redirect(to: "/")}
    else
      if connected?(socket) do
        Claper.Events.Event.subscribe(event.uuid)
        Claper.Presentations.subscribe(event.presentation_file.id)

        Presence.track(
          self(),
          "event:#{event.uuid}",
          socket.assigns.current_user.id,
          %{}
        )
      end

      endpoint_config = Application.get_env(:claper, ClaperWeb.Endpoint)[:url]
      port = endpoint_config[:port]
      scheme = endpoint_config[:scheme]
      host = endpoint_config[:host]
      path = endpoint_config[:path]

      default_ports = [80, 443]
      port_suffix = if port in default_ports, do: "", else: ":" <> Integer.to_string(port)

      host = "#{scheme}://#{host}#{port_suffix}/#{path}"

      socket =
        socket
        |> assign(:attendees_nb, 1)
        |> assign(
          :host,
          host
        )
        |> assign(:event, event)
        |> assign(:state, event.presentation_file.presentation_state)
        |> assign(:posts, list_posts(socket, event.uuid))
        |> assign(:pinned_posts, list_pinned_posts(socket, event.uuid))
        |> assign(:show_only_pinned, event.presentation_file.presentation_state.show_only_pinned)
        |> assign(:reacts, [])
        |> poll_at_position
        |> form_at_position
        |> embed_at_position

      {:ok, socket, temporary_assigns: []}
    end
  end

  defp update_post_in_list(posts, updated_post) do
    Enum.map(posts, fn post ->
      if post.id == updated_post.id, do: updated_post, else: post
    end)
  end

  defp is_leader(%{assigns: %{current_user: current_user}} = _socket, event) do
    Claper.Events.is_leaded_by(current_user.email, event) || event.user.id == current_user.id
  end

  defp is_leader(_socket, _event), do: false

  @impl true
  def handle_info(%{event: "presence_diff"}, %{assigns: %{event: event}} = socket) do
    attendees = Presence.list("event:#{event.uuid}")
    {:noreply, assign(socket, :attendees_nb, Enum.count(attendees))}
  end

  @impl true
  def handle_info({:post_created, post}, socket) do
    {:noreply,
     socket
     |> update(:posts, fn posts -> posts ++ [post] end)}
  end

  @impl true
  def handle_info({:post_pinned, post}, socket) do
    {:noreply,
     socket
     |> update(:pinned_posts, fn pinned_posts -> pinned_posts ++ [post] end)}
  end

  @impl true
  def handle_info({:post_unpinned, post}, socket) do
    {:noreply,
     socket
     |> update(:pinned_posts, fn pinned_posts ->
       Enum.reject(pinned_posts, fn p -> p.id == post.id end)
     end)}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:state, state)
     |> push_event("page", %{current_page: state.position})
     |> push_event("reset-global-react", %{})
     |> poll_at_position
     |> embed_at_position}
  end

  @impl true
  def handle_info({:post_updated, updated_post}, socket) do
    updated_posts = update_post_in_list(socket.assigns.posts, updated_post)
    updated_pinned_posts = update_post_in_list(socket.assigns.pinned_posts, updated_post)

    {:noreply,
     socket
     |> assign(:posts, updated_posts)
     |> assign(:pinned_posts, updated_pinned_posts)}
  end

  @impl true
  def handle_info({:post_deleted, post}, socket) do
    updated_posts = Enum.reject(socket.assigns.posts, fn p -> p.id == post.id end)
    updated_pinned_posts = Enum.reject(socket.assigns.pinned_posts, fn p -> p.id == post.id end)

    {:noreply,
     socket |> assign(:posts, updated_posts) |> assign(:pinned_posts, updated_pinned_posts)}
  end

  @impl true
  def handle_info({:poll_updated, poll}, socket) do
    if poll.enabled do
      {:noreply,
       socket
       |> update(:current_poll, fn _current_poll -> poll end)}
    else
      {:noreply,
       socket
       |> update(:current_poll, fn _current_poll -> nil end)}
    end
  end

  @impl true
  def handle_info({:poll_deleted, _poll}, socket) do
    {:noreply,
     socket
     |> update(:current_poll, fn _current_poll -> nil end)}
  end

  @impl true
  def handle_info({:form_updated, form}, socket) do
    if form.active do
      {:noreply,
       socket
       |> update(:current_form, fn _current_form -> form end)}
    else
      {:noreply,
       socket
       |> update(:current_form, fn _current_form -> nil end)}
    end
  end

  @impl true
  def handle_info({:form_deleted, _form}, socket) do
    {:noreply,
     socket
     |> update(:current_form, fn _current_form -> nil end)}
  end

  @impl true
  def handle_info({:embed_updated, embed}, socket) do
    if embed.enabled do
      {:noreply,
       socket
       |> update(:current_embed, fn _current_embed -> embed end)}
    else
      {:noreply,
       socket
       |> update(:current_embed, fn _current_embed -> nil end)}
    end
  end

  @impl true
  def handle_info({:embed_deleted, _embed}, socket) do
    {:noreply,
     socket
     |> update(:current_embed, fn _current_embed -> nil end)}
  end

  @impl true
  def handle_info({:chat_visible, value}, socket) do
    {:noreply,
     socket
     |> push_event("chat-visible", %{value: value})
     |> update(:chat_visible, fn _chat_visible -> value end)}
  end

  @impl true
  def handle_info({:show_only_pinned, value}, socket) do
    {:noreply,
     socket
     |> push_event("show_only_pinned", %{value: value})
     |> update(:show_only_pinned, fn _show_only_pinned -> value end)}
  end

  @impl true
  def handle_info({:poll_visible, value}, socket) do
    {:noreply,
     socket
     |> push_event("poll-visible", %{value: value})
     |> update(:poll_visible, fn _poll_visible -> value end)}
  end

  @impl true
  def handle_info({:join_screen_visible, value}, socket) do
    {:noreply,
     socket
     |> push_event("join-screen-visible", %{value: value})
     |> update(:join_screen_visible, fn _join_screen_visible -> value end)}
  end

  @impl true
  def handle_info({:react, type}, socket) do
    {:noreply,
     socket
     |> push_event("global-react", %{type: type})}
  end

  @impl true
  def handle_info(
        {:current_poll, poll},
        socket
      ) do
    {:noreply, socket |> assign(:current_poll, poll)}
  end

  @impl true
  def handle_info(
        {:current_form, form},
        socket
      ) do
    {:noreply, socket |> assign(:current_form, form)}
  end

  @impl true
  def handle_info(
        {:current_embed, embed},
        socket
      ) do
    {:noreply, socket |> assign(:current_embed, embed)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp poll_at_position(%{assigns: %{event: event, state: state}} = socket) do
    with poll <-
           Claper.Polls.get_poll_current_position(
             event.presentation_file.id,
             state.position
           ) do
      socket |> assign(:current_poll, poll)
    end
  end

  defp form_at_position(%{assigns: %{event: event, state: state}} = socket) do
    with form <-
           Claper.Forms.get_form_current_position(
             event.presentation_file.id,
             state.position
           ) do
      socket |> assign(:current_form, form)
    end
  end

  defp embed_at_position(%{assigns: %{event: event, state: state}} = socket) do
    with embed <-
           Claper.Embeds.get_embed_current_position(
             event.presentation_file.id,
             state.position
           ) do
      socket |> assign(:current_embed, embed)
    end
  end

  defp list_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end

  defp list_pinned_posts(_socket, event_id) do
    Claper.Posts.list_pinned_posts(event_id, [:event, :reactions])
  end
end
