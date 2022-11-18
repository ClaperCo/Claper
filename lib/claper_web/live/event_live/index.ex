defmodule ClaperWeb.EventLive.Index do
  use ClaperWeb, :live_view

  alias Claper.Events
  alias Claper.Events.Event

  on_mount(ClaperWeb.UserLiveAuth)

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Claper.PubSub, "events:#{socket.assigns.current_user.id}")
    end

    socket =
      socket
      |> assign(:events, list_events(socket))
      |> assign(:managed_events, list_managed_events(socket))

    {:ok, socket, temporary_assigns: [events: []]}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_info({:presentation_file_process_done, presentation}, socket) do
    event = Claper.Events.get_event!(presentation.event.uuid, [:presentation_file])

    {:noreply,
     socket |> update(:events, fn events -> [event | events] end) |> put_flash(:info, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Events.get_event!(id, [:presentation_file])
    {:ok, _} = Events.delete_event(event)

    Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
      Claper.Tasks.Converter.clear(event.presentation_file.hash)
    end)

    {:noreply, redirect(socket, to: Routes.event_index_path(socket, :index))}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    event =
      Events.get_user_event!(socket.assigns.current_user.id, id, [:presentation_file, :leaders])

    if event.presentation_file.status == "fail" && event.presentation_file.hash do
      Claper.Presentations.update_presentation_file(event.presentation_file, %{
        "status" => "done"
      })
    end

    {:ok, socket |> assign(:event, event)}

    socket
    |> assign(:page_title, gettext("Edit"))
    |> assign(:event, event)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("Create"))
    |> assign(:event, %Event{
      started_at: NaiveDateTime.utc_now(),
      expired_at: NaiveDateTime.utc_now() |> NaiveDateTime.add(3600 * 2, :second),
      code: Enum.random(1000..9999),
      leaders: []
    })
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Dashboard"))
    |> assign(:event, nil)
  end

  defp list_events(socket) do
    Events.list_events(socket.assigns.current_user.id, [:presentation_file])
  end

  defp list_managed_events(socket) do
    Events.list_managed_events_by(socket.assigns.current_user.email, [:presentation_file])
  end
end
