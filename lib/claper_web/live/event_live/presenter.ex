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
       |> put_flash(:error, gettext("Presentation doesn't exist"))
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

      socket =
        socket
        |> assign(:attendees_nb, 1)
        |> assign(:event, event)
        |> assign(:state, event.presentation_file.presentation_state)
        |> assign(:posts, list_posts(socket, event.uuid))
        |> assign(:reacts, [])
        |> poll_at_position

      {:ok, socket, temporary_assigns: [posts: []]}
    end
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
     |> update(:posts, fn posts -> [post | posts] end)}
  end

  @impl true
  def handle_info({:state_updated, state}, socket) do
    {:noreply,
     socket
     |> assign(:state, state)
     |> push_event("page", %{current_page: state.position})
     |> push_event("reset-global-react", %{})
     |> poll_at_position}
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
     |> update(:current_form, fn _current_form -> nil end)}
  end

  @impl true
  def handle_info({:chat_visible, value}, socket) do
    {:noreply,
     socket
     |> push_event("chat-visible", %{value: value})
     |> update(:chat_visible, fn _chat_visible -> value end)}
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

  defp list_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end
end
