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
      |> assign(:folder, nil)
      |> assign(:folder_loaded, false)
      |> assign(:breadcrumbs, [])
      |> assign(:path, [])
      |> assign(:subfolders, [])
      |> assign(:creating_folder, false)
      |> assign(:editing_folder, nil)
      |> assign(:folder_edit_options, [])
      |> assign(:view_mode, "grid")
      |> assign(:temporary_assigns, events: [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case fetch_folder(socket, params) do
      {:ok, folder} ->
        # Editing shows the folder of the event, which apply_action resolves
        socket =
          if socket.assigns.live_action == :edit, do: socket, else: set_folder(socket, folder)

        {:noreply, apply_action(socket, socket.assigns.live_action, params)}

      :error ->
        {:noreply, push_navigate(socket, to: ~p"/events")}
    end
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
    event = Events.get_user_event!(current_user.id, id, [:presentation_file])

    files = Claper.Presentations.get_presentation_files_by_hash(event.presentation_file.hash)
    {:ok, _} = Events.delete_event(event)
    clear_presentation_files(event, files)

    {:noreply, redirect(socket, to: folder_href(socket.assigns.path))}
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
    {:noreply, redirect(socket, to: folder_href(socket.assigns.path))}
  end

  @impl true
  def handle_event("duplicate", %{"id" => id}, %{assigns: %{current_user: current_user}} = socket) do
    event = Events.get_user_event!(current_user.id, id)
    {:ok, _} = Events.duplicate_event(current_user.id, event.uuid)
    {:noreply, redirect(socket, to: folder_href(socket.assigns.path))}
  end

  @impl true
  def handle_event("create-folder", %{"name" => name}, socket) do
    parent_id = socket.assigns.folder && socket.assigns.folder.id

    case Events.create_folder(socket.assigns.current_user.id, %{
           "name" => name,
           "parent_id" => parent_id
         }) do
      {:ok, _folder} -> {:noreply, socket |> assign(:creating_folder, false) |> refresh_events()}
      {:error, _changeset} -> {:noreply, folder_error(socket)}
    end
  end

  @impl true
  def handle_event("toggle-create-folder", _params, socket) do
    {:noreply, assign(socket, :creating_folder, !socket.assigns.creating_folder)}
  end

  @impl true
  def handle_event("edit-folder", %{"uuid" => uuid}, socket) do
    user_id = socket.assigns.current_user.id
    folder = Events.get_user_folder_by_uuid!(user_id, uuid)

    {:noreply,
     socket
     |> assign(:editing_folder, folder)
     |> assign(:folder_edit_options, Events.folder_options(user_id, exclude: folder))}
  end

  @impl true
  def handle_event("close-folder-editor", _params, socket) do
    {:noreply, assign(socket, :editing_folder, nil)}
  end

  @impl true
  def handle_event("save-folder", %{"name" => name, "parent_id" => parent_id}, socket) do
    case Events.update_folder(socket.assigns.editing_folder, %{
           "name" => name,
           "parent_id" => parent_id
         }) do
      {:ok, _folder} ->
        {:noreply, socket |> assign(:editing_folder, nil) |> refresh_events()}

      {:error, _changeset} ->
        {:noreply, folder_error(socket)}
    end
  end

  @impl true
  def handle_event("delete-folder", params, socket) do
    delete_events? = params["delete_events"] == "true"

    case Events.delete_folder(socket.assigns.editing_folder, delete_events: delete_events?) do
      {:ok, %{deleted_events: events}} ->
        Enum.each(events, &clear_presentation_files/1)
        {:noreply, socket |> assign(:editing_folder, nil) |> refresh_events()}

      {:error, :name_conflict} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext("A folder with the same name already exists one level up")
         )}
    end
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
      Events.get_user_event!(socket.assigns.current_user.id, id, [
        :presentation_file,
        :leaders,
        :folder
      ])

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
      |> set_folder(event.folder)
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
      leaders: [],
      folder_id: socket.assigns.folder && socket.assigns.folder.id
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

    # Searching spans all folders
    params =
      if socket.assigns.search_query in [nil, ""],
        do: Map.put(params, "folder_id", socket.assigns.folder && socket.assigns.folder.id),
        else: params

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

  # Folders are addressed by the names from the top level down: /events/folders/Courses/Elixir.
  # A new event takes the folder from the query: /events/new?folder=Courses/Elixir.
  defp fetch_folder(socket, %{"path" => names}) when is_list(names),
    do: find_folder(socket, names)

  defp fetch_folder(socket, %{"folder" => path}) when is_binary(path),
    do: find_folder(socket, String.split(path, "/", trim: true))

  defp fetch_folder(_socket, _params), do: {:ok, nil}

  defp find_folder(_socket, []), do: {:ok, nil}

  defp find_folder(socket, names) do
    {:ok, Events.get_user_folder_by_path!(socket.assigns.current_user.id, names)}
  rescue
    Ecto.NoResultsError -> :error
  end

  # Opens a folder (nil is the top level) and loads its events, unless it is already open
  defp set_folder(socket, folder) do
    if socket.assigns.folder_loaded && same_folder?(socket.assigns.folder, folder) do
      socket
    else
      socket
      |> assign(:folder_loaded, true)
      |> assign_folder(folder)
      |> assign(:page, 1)
      |> assign(:events, [])
      |> load_events()
    end
  end

  defp same_folder?(nil, nil), do: true
  defp same_folder?(%{id: id}, %{id: id}), do: true
  defp same_folder?(_, _), do: false

  defp assign_folder(socket, folder) do
    user_id = socket.assigns.current_user.id
    breadcrumbs = if folder, do: Events.folder_path(folder), else: []

    socket
    |> assign(:folder, folder)
    |> assign(:breadcrumbs, breadcrumbs)
    |> assign(:path, Enum.map(breadcrumbs, & &1.name))
    |> assign(:subfolders, Events.list_child_folders(user_id, folder && folder.id))
  end

  # Removes the converted slides once no other presentation file shares them
  defp clear_presentation_files(event) do
    hash = presentation_hash(event)
    clear_presentation_files(event, Claper.Presentations.get_presentation_files_by_hash(hash))
  end

  defp clear_presentation_files(event, remaining_files) do
    hash = presentation_hash(event)

    if Enum.empty?(remaining_files) && !is_nil(hash) do
      Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
        Claper.Tasks.Converter.clear(hash)
      end)
    end
  end

  defp presentation_hash(%{presentation_file: %{hash: hash}}), do: hash
  defp presentation_hash(_event), do: nil

  defp folder_error(socket),
    do: put_flash(socket, :error, gettext("Folder name is invalid or already used"))

  # Folders are listed only at the top of the Active and Done tabs, not while searching
  defp show_folders?(%{search_query: "", active_tab: tab}), do: tab != "invited"
  defp show_folders?(_assigns), do: false

  attr :prefix, :string, required: true
  attr :open, :boolean, required: true

  def create_folder_control(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <form
        :if={@open}
        id={"#{@prefix}-form"}
        phx-submit="create-folder"
        class="flex items-center gap-1"
      >
        <input
          id={"#{@prefix}-input"}
          type="text"
          name="name"
          maxlength="50"
          required
          autocomplete="off"
          placeholder={gettext("Folder name")}
          aria-label={gettext("Folder name")}
          phx-mounted={JS.focus()}
          phx-keydown="toggle-create-folder"
          phx-key="Escape"
          class="input input-bordered h-12 w-48 bg-white"
        />
        <button type="submit" class="btn btn-primary h-12">{gettext("Create folder")}</button>
      </form>
      <button
        id={"#{@prefix}-toggle"}
        type="button"
        phx-click="toggle-create-folder"
        aria-label={gettext("New folder")}
        aria-expanded={to_string(@open)}
        title={gettext("New folder")}
        class="flex h-12 w-12 items-center justify-center rounded-full border border-gray-200 bg-white transition hover:bg-gray-100"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5 text-secondary-500"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="1.5"
          aria-hidden="true"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 10.5v6m3-3H9m4.06-7.19l-2.12-2.12a1.5 1.5 0 00-1.061-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"
          />
        </svg>
      </button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :folder, :map, required: true
  attr :href, :string, required: true
  attr :layout, :string, default: "row", doc: ~s("grid" is a large card, anything else a slim row)

  def folder_card(%{layout: "grid"} = assigns) do
    ~H"""
    <div
      id={@id}
      class="group relative h-96 overflow-hidden rounded-2xl border border-gray-200 bg-white transition-shadow duration-200 hover:shadow-lg"
    >
      <.link
        patch={@href}
        aria-label={@folder.name}
        class="absolute inset-0 flex items-center justify-center bg-gray-100 pb-16"
      >
        <.folder_icon class="h-32 w-32 text-primary opacity-80" />
      </.link>
      <div class="absolute bottom-0 left-0 right-0 flex items-center justify-between gap-4 border-t border-gray-200 bg-white p-2">
        <h3 class="min-w-0 truncate font-bold text-gray-800">{@folder.name}</h3>
        <.edit_folder_button folder={@folder} />
      </div>
    </div>
    """
  end

  def folder_card(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex items-center gap-1 rounded-box border border-base-300 bg-base-100 transition hover:bg-base-200"
    >
      <.link patch={@href} class="flex min-w-0 flex-1 items-center gap-3 py-3 pl-4">
        <.folder_icon class="h-6 w-6 shrink-0 text-primary" />
        <span class="truncate font-semibold">{@folder.name}</span>
      </.link>
      <div class="pr-2">
        <.edit_folder_button folder={@folder} />
      </div>
    </div>
    """
  end

  attr :class, :string, required: true

  defp folder_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class={@class}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      stroke-width="1.5"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M2.25 12.75V12A2.25 2.25 0 014.5 9.75h15A2.25 2.25 0 0121.75 12v.75m-8.69-6.44l-2.12-2.12a1.5 1.5 0 00-1.06-.44H4.5A2.25 2.25 0 002.25 6v12a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9a2.25 2.25 0 00-2.25-2.25h-5.379a1.5 1.5 0 01-1.06-.44z"
      />
    </svg>
    """
  end

  attr :folder, :map, required: true

  defp edit_folder_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="edit-folder"
      phx-value-uuid={@folder.uuid}
      aria-label={gettext("Edit folder")}
      title={gettext("Edit folder")}
      class="btn btn-ghost btn-circle btn-sm shrink-0"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="h-5 w-5 text-secondary-500"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="1.5"
        aria-hidden="true"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"
        />
      </svg>
    </button>
    """
  end

  # `path` is the list of folder names from the top level down
  defp folder_href([]), do: ~p"/events"
  defp folder_href(path), do: ~p"/events/folders/#{path}"

  defp new_event_href([]), do: ~p"/events/new"
  # RFC 3986 so spaces become %20 (as in the folder path), not +
  defp new_event_href(path),
    do: ~p"/events/new" <> "?" <> URI.encode_query([folder: Enum.join(path, "/")], :rfc3986)

  defp refresh_events(socket) do
    expired_events_count = Events.count_expired_events(socket.assigns.current_user.id)
    invited_events_count = Events.count_managed_events_by(socket.assigns.current_user.email)

    socket
    |> assign_folder(socket.assigns.folder)
    |> assign(:has_expired_events, expired_events_count > 0)
    |> assign(:has_invited_events, invited_events_count > 0)
    |> assign(:events, [])
    |> assign(:page, 1)
    |> load_events()
  end
end
