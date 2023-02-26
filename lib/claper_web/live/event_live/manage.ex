defmodule ClaperWeb.EventLive.Manage do
  use ClaperWeb, :live_view

  alias ClaperWeb.Presence
  alias Claper.Polls
  alias Claper.Forms

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
        # Claper.Presentations.subscribe(event.presentation_file.id)

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
        |> assign(:polls, list_polls(socket, event.presentation_file.id))
        |> assign(:forms, list_forms(socket, event.presentation_file.id))
        |> assign(:create, nil)
        |> assign(:list_tab, :posts)
        |> assign(:create_action, :new)
        |> push_event("page-manage", %{
          current_page: event.presentation_file.presentation_state.position,
          timeout: 500
        })
        |> poll_at_position(false)

      {:ok, socket, temporary_assigns: [posts: [], form_submits: []]}
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
     socket |> update(:posts, fn posts -> [post | posts] end) |> push_event("scroll", %{})}
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
  def handle_info({:form_submit_created, fs}, socket) do
    {:noreply,
     socket |> update(:form_submits, fn form_submits -> [fs | form_submits] end) |> push_event("scroll", %{})}
  end

  @impl true
  def handle_info({:form_submit_updated, fs}, socket) do
    {:noreply, socket |> update(:form_submits, fn form_submits -> [fs | form_submits] end)}
  end

  @impl true
  def handle_info({:form_submit_deleted, fs}, socket) do
    {:noreply, socket |> update(:form_submits, fn form_submits -> [fs | form_submits] end)}
  end

  @impl true
  def handle_info({:poll_updated, poll}, socket) do
    {:noreply,
     socket
     |> update(:current_poll, fn _current_poll -> poll end)}
  end

  @impl true
  def handle_info(
        {:current_poll, poll},
        socket
      ) do
    {:noreply, socket |> assign(:current_poll, poll)}
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
     |> poll_at_position}
  end

  def handle_event("poll-set-default", %{"id" => id}, socket) do
    Forms.disable_all(socket.assigns.event.presentation_file.id, socket.assigns.state.position)
    Polls.set_default(
      id,
      socket.assigns.event.presentation_file.id,
      socket.assigns.state.position
    )

    poll = Polls.get_poll!(id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:current_poll, poll}
    )

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:current_form, nil}
    )

    {:noreply,
     socket
     |> assign(:polls, list_polls(socket, socket.assigns.event.presentation_file.id))
     |> assign(:forms, list_forms(socket, socket.assigns.event.presentation_file.id))
    }
  end
  def handle_event("form-set-default", %{"id" => id}, socket) do
    Polls.disable_all(socket.assigns.event.presentation_file.id, socket.assigns.state.position)
    Forms.set_default(
      id,
      socket.assigns.event.presentation_file.id,
      socket.assigns.state.position
    )

    form = Forms.get_form!(id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:current_form, form}
    )

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event.uuid}",
      {:current_poll, nil}
    )

    {:noreply,
     socket
     |> assign(:polls, list_polls(socket, socket.assigns.event.presentation_file.id))
     |> assign(:forms, list_forms(socket, socket.assigns.event.presentation_file.id))}
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
  def handle_event("delete", %{"event-id" => event_id, "id" => id}, socket) do
    post = Claper.Posts.get_post!(id, [:event])
    {:ok, _} = Claper.Posts.delete_post(post)

    {:noreply, assign(socket, :posts, list_posts(socket, event_id))}
  end

  @impl true
  def handle_event("delete-form-submit", %{"event-id" => event_id, "id" => id}, socket) do
    form = Claper.Forms.get_form_submit_by_id!(id)
    {:ok, _} = Claper.Forms.delete_form_submit(event_id, form)

    {:noreply, assign(socket, :form_submits, list_form_submits(socket, socket.assigns.event.presentation_file.id))}
  end

  @impl true
  def handle_event("list-tab", %{"tab" => tab}, socket) do
    socket = assign(socket, :list_tab, String.to_atom(tab))
    socket = case tab do
      "posts" -> assign(socket, :posts, list_posts(socket, socket.assigns.event.uuid))
      "forms" -> assign(socket, :form_submits, list_form_submits(socket, socket.assigns.event.presentation_file.id))
    end
    {:noreply,socket}
  end

  @impl true
  def handle_event("maybe-redirect", _params, socket) do
    if socket.assigns.create != nil do
      {:noreply,
       socket
       |> push_redirect(to: Routes.event_manage_path(socket, :show, socket.assigns.event.code))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete-poll", %{"id" => id}, socket) do
    poll = Polls.get_poll!(id)
    {:ok, _} = Polls.delete_poll(socket.assigns.event.uuid, poll)

    {:noreply,
     socket
     |> assign(:polls, list_polls(socket, socket.assigns.event.presentation_file.id))}
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

  defp apply_action(socket, :show, _params) do
    socket
  end

  defp apply_action(socket, :add_poll, _params) do
    socket
    |> assign(:create, "poll")
    |> assign(:poll, %Polls.Poll{
      poll_opts: [%Polls.PollOpt{id: 0}, %Polls.PollOpt{id: 1}]
    })
  end

  defp apply_action(socket, :edit_poll, %{"id" => id}) do
    poll = Polls.get_poll!(id)

    socket
    |> assign(:create, "poll")
    |> assign(:create_action, :edit)
    |> assign(:poll, poll)
  end

  defp apply_action(socket, :add_form, _params) do
    socket
    |> assign(:create, "form")
    |> assign(:form, %Forms.Form{
      fields: [%Forms.Field{name: gettext("Name"), type: "text"}, %Forms.Field{name: gettext("Email"), type: "email"}]
    })
  end

  defp apply_action(socket, :edit_form, %{"id" => id}) do
    form = Forms.get_form!(id)

    socket
    |> assign(:create, "form")
    |> assign(:create_action, :edit)
    |> assign(:form, form)
  end

  defp poll_at_position(
         %{assigns: %{event: event, state: state}} = socket,
         broadcast \\ true
       ) do
    with poll <-
           Claper.Polls.get_poll_current_position(
             event.presentation_file.id,
             state.position
           ) do
      if broadcast do
        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{event.uuid}",
          {:current_poll, poll}
        )
      end

      socket |> assign(:current_poll, poll)
    end
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

  defp list_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end

  defp list_polls(_socket, presentation_file_id) do
    Claper.Polls.list_polls(presentation_file_id)
  end

  defp list_forms(_socket, presentation_file_id) do
    Claper.Forms.list_forms(presentation_file_id)
  end

  defp list_form_submits(_socket, presentation_file_id) do
    Claper.Forms.list_form_submits(presentation_file_id)
  end

end
