defmodule ClaperWeb.EventLive.Index do
  use ClaperWeb, :live_view

  alias Claper.{Events, Presentations}
  alias Claper.Events.Event

  on_mount(ClaperWeb.UserLiveAuth)

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    if connected?(socket) do
      Events.subscribe_user_events(socket.assigns.current_user.id)
    end

    expired_events_count = Events.count_expired_events(socket.assigns.current_user.id)
    invited_events_count = Events.count_managed_events_by(socket.assigns.current_user.email)

    socket =
      socket
      |> assign(:active_tab, "not_expired")
      |> assign(:has_expired_events, expired_events_count > 0)
      |> assign(:has_invited_events, invited_events_count > 0)
      |> assign(:page, 1)
      |> assign(:total_pages, 1)
      |> assign(:total_entries, 0)
      |> assign(:events, [])
      |> assign(:search_query, "")
      |> assign(:view_mode, "grid")
      |> assign(:temporary_assigns, events: [])
      |> load_events()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({type, %Events.Event{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, refresh_events(socket)}
  end

  @impl true
  def handle_info({type, %Presentations.PresentationFile{}}, socket)
      when type in [:presentation_file_process_done] do
    {:noreply, refresh_events(socket)}
  end

  @impl true
  def handle_info(message, socket) do
    IO.puts("Received unknown message `#{inspect(message)}` in #{__MODULE__} #{inspect(self())}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{current_user: current_user}} = socket) do
    event = Events.get_user_event!(current_user.id, id)
    {:ok, _} = Events.delete_event(event)

    {:noreply, redirect(socket, to: ~p"/events")}
  end

  @impl true
  def handle_event(
        "checked",
        %{"key" => "no_file", "value" => value},
        %{assigns: %{event: event}} = socket
      ) do
    {:noreply, socket |> assign(:event, %{event | no_file: value})}
  end

  @impl true
  def handle_event("terminate", %{"id" => id}, %{assigns: %{current_user: current_user}} = socket) do
    event = Events.get_user_event!(current_user.id, id)
    {:ok, _} = Events.terminate_event(event)
    {:noreply, redirect(socket, to: ~p"/events")}
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, %{assigns: %{current_user: current_user}} = socket) do
    event = Events.get_user_event!(current_user.id, id)
    {:ok, _} = Events.duplicate_event(current_user.id, event.uuid)
    {:noreply, redirect(socket, to: ~p"/events")}
  end

  @impl true
  def handle_event("change-tab", %{"tab" => tab}, socket) do
    socket =
      socket
      |> assign(:active_tab, tab)
      |> assign(:page, 1)
      |> assign(:events, [])
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load-more", _, socket) do
    if socket.assigns.page < socket.assigns.total_pages do
      {:noreply, socket |> assign(:page, socket.assigns.page + 1) |> load_events()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search_query}, socket) do
    socket =
      socket
      |> assign(:search_query, search_query)
      |> assign(:page, 1)
      |> assign(:events, [])
      |> load_events()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change-view", %{"view" => view_mode}, socket) do
    {:noreply,
     socket
     |> assign(:view_mode, view_mode)
     |> push_event("save-view-mode", %{view: view_mode})}
  end

  @impl true
  def handle_event("restore-view-mode", %{"view" => view_mode}, socket) do
    {:noreply, assign(socket, :view_mode, view_mode)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event =
      Events.get_user_event!(socket.assigns.current_user.id, id, [:presentation_file, :leaders])

    if event.expired_at && NaiveDateTime.compare(NaiveDateTime.utc_now(), event.expired_at) == :gt do
      redirect(socket, to: ~p"/events")
    else
      if event.presentation_file.status == "fail" && event.presentation_file.hash do
        Claper.Presentations.update_presentation_file(event.presentation_file, %{
          "status" => "done"
        })
      end

      {:ok, socket |> assign(:event, event)}

      socket
      |> assign(:page_title, gettext("Edit event"))
      |> assign(:event, event)
    end
  rescue
    Ecto.NoResultsError ->
      socket
      |> put_flash(:error, gettext("Event doesn't exist"))
      |> redirect(to: ~p"/events")
  end

  defp apply_action(socket, :new, _params) do
    code = for _ <- 1..5, into: "", do: <<Enum.random(~c"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")>>

    socket
    |> assign(:page_title, gettext("Create event"))
    |> assign(:event, %Event{
      started_at: NaiveDateTime.utc_now(),
      code: code,
      leaders: []
    })
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Dashboard"))
    |> assign(:event, nil)
  end

  defp load_events(socket) do
    params = %{
      "page" => socket.assigns.page,
      "page_size" => 6,
      "search" => socket.assigns.search_query
    }

    {events, total_entries, total_pages} =
      case socket.assigns.active_tab do
        "not_expired" ->
          Events.paginate_not_expired_events(socket.assigns.current_user.id, params, [
            :presentation_file,
            :lti_resource
          ])

        "expired" ->
          Events.paginate_expired_events(socket.assigns.current_user.id, params, [
            :presentation_file,
            :lti_resource
          ])

        "invited" ->
          Events.paginate_managed_events_by(socket.assigns.current_user.email, params, [
            :presentation_file,
            :lti_resource
          ])
      end

    socket
    |> assign(:total_entries, total_entries)
    |> assign(:total_pages, total_pages)
    |> assign(
      :events,
      if(socket.assigns.page == 1, do: events, else: socket.assigns.events ++ events)
    )
  end

  defp refresh_events(socket) do
    expired_events_count = Events.count_expired_events(socket.assigns.current_user.id)
    invited_events_count = Events.count_managed_events_by(socket.assigns.current_user.email)

    socket
    |> assign(:has_expired_events, expired_events_count > 0)
    |> assign(:has_invited_events, invited_events_count > 0)
    |> assign(:events, [])
    |> assign(:page, 1)
    |> load_events()
  end
end
