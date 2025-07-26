defmodule ClaperWeb.AdminLive.TableActionsComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center space-x-2">
      <%= if @view_enabled do %>
        <button
          type="button"
          phx-click="view_item"
          phx-target={@myself}
          class="text-indigo-600 hover:text-indigo-900 transition-colors duration-200"
          title="View"
        >
          <i class="fas fa-eye"></i>
          <span class="sr-only">View</span>
        </button>
      <% end %>

      <%= if @edit_enabled do %>
        <button
          type="button"
          phx-click="edit_item"
          phx-target={@myself}
          class="text-indigo-600 hover:text-indigo-900 transition-colors duration-200"
          title="Edit"
        >
          <i class="fas fa-edit"></i>
          <span class="sr-only">Edit</span>
        </button>
      <% end %>

      <%= if @delete_enabled do %>
        <button
          type="button"
          phx-click="delete_item"
          phx-target={@myself}
          class="text-red-600 hover:text-red-900 transition-colors duration-200"
          title="Delete"
          data-confirm={
            @delete_confirm_message ||
              "Are you sure you want to delete this item? This action cannot be undone."
          }
        >
          <i class="fas fa-trash-alt"></i>
          <span class="sr-only">Delete</span>
        </button>
      <% end %>

      <%= if @duplicate_enabled do %>
        <button
          type="button"
          phx-click="duplicate_item"
          phx-target={@myself}
          class="text-green-600 hover:text-green-900 transition-colors duration-200"
          title="Duplicate"
        >
          <i class="fas fa-copy"></i>
          <span class="sr-only">Duplicate</span>
        </button>
      <% end %>

      <%= if @archive_enabled do %>
        <button
          type="button"
          phx-click="archive_item"
          phx-target={@myself}
          class={[
            "transition-colors duration-200",
            if(@item_archived,
              do: "text-orange-600 hover:text-orange-900",
              else: "text-gray-600 hover:text-gray-900"
            )
          ]}
          title={if @item_archived, do: "Unarchive", else: "Archive"}
        >
          <i class={if @item_archived, do: "fas fa-box-open", else: "fas fa-archive"}></i>
          <span class="sr-only">{if @item_archived, do: "Unarchive", else: "Archive"}</span>
        </button>
      <% end %>

      <%= if @toggle_enabled do %>
        <button
          type="button"
          phx-click="toggle_item"
          phx-target={@myself}
          class={[
            "transition-colors duration-200",
            if(@item_active,
              do: "text-green-600 hover:text-green-900",
              else: "text-gray-600 hover:text-gray-900"
            )
          ]}
          title={
            if @item_active,
              do: @toggle_active_title || "Deactivate",
              else: @toggle_inactive_title || "Activate"
          }
        >
          <i class={if @item_active, do: "fas fa-toggle-on", else: "fas fa-toggle-off"}></i>
          <span class="sr-only">
            {if @item_active,
              do: @toggle_active_title || "Deactivate",
              else: @toggle_inactive_title || "Activate"}
          </span>
        </button>
      <% end %>

      <%= if @dropdown_actions && length(@dropdown_actions) > 0 do %>
        <div class="relative" phx-click-away="close_dropdown" phx-target={@myself}>
          <button
            type="button"
            phx-click="toggle_dropdown"
            phx-target={@myself}
            class="text-gray-600 hover:text-gray-900 transition-colors duration-200"
            title="More actions"
          >
            <i class="fas fa-ellipsis-v"></i>
            <span class="sr-only">More actions</span>
          </button>

          <%= if @dropdown_open do %>
            <div class="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg z-10 border border-gray-200">
              <div class="py-1">
                <%= for action <- @dropdown_actions do %>
                  <button
                    type="button"
                    phx-click="dropdown_action"
                    phx-value-action={action.key}
                    phx-target={@myself}
                    class={[
                      "block w-full text-left px-4 py-2 text-sm transition-colors duration-200",
                      case action.type do
                        "danger" -> "text-red-700 hover:bg-red-50"
                        "warning" -> "text-orange-700 hover:bg-orange-50"
                        _ -> "text-gray-700 hover:bg-gray-50"
                      end
                    ]}
                    data-confirm={action[:confirm]}
                  >
                    <%= if action[:icon] do %>
                      <i class={"#{action.icon} mr-2"}></i>
                    <% end %>
                    {action.label}
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @custom_actions do %>
        {render_slot(@custom_actions)}
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, dropdown_open: false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:view_enabled, fn -> false end)
      |> assign_new(:edit_enabled, fn -> true end)
      |> assign_new(:delete_enabled, fn -> true end)
      |> assign_new(:duplicate_enabled, fn -> false end)
      |> assign_new(:archive_enabled, fn -> false end)
      |> assign_new(:toggle_enabled, fn -> false end)
      |> assign_new(:item_archived, fn -> false end)
      |> assign_new(:item_active, fn -> true end)
      |> assign_new(:delete_confirm_message, fn -> nil end)
      |> assign_new(:toggle_active_title, fn -> nil end)
      |> assign_new(:toggle_inactive_title, fn -> nil end)
      |> assign_new(:dropdown_actions, fn -> [] end)
      |> assign_new(:custom_actions, fn -> [] end)
      |> assign_new(:dropdown_open, fn -> false end)

    {:ok, socket}
  end

  @impl true
  def handle_event("view_item", _params, socket) do
    send(self(), {:table_action, :view, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("edit_item", _params, socket) do
    send(self(), {:table_action, :edit, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("delete_item", _params, socket) do
    send(self(), {:table_action, :delete, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("duplicate_item", _params, socket) do
    send(self(), {:table_action, :duplicate, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("archive_item", _params, socket) do
    action = if socket.assigns.item_archived, do: :unarchive, else: :archive
    send(self(), {:table_action, action, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("toggle_item", _params, socket) do
    action = if socket.assigns.item_active, do: :deactivate, else: :activate
    send(self(), {:table_action, action, socket.assigns.item, socket.assigns.item_id})
    {:noreply, socket}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: !socket.assigns.dropdown_open)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  def handle_event("dropdown_action", %{"action" => action_key}, socket) do
    action = Enum.find(socket.assigns.dropdown_actions, &(&1.key == action_key))

    if action do
      send(
        self(),
        {:table_action, String.to_atom(action_key), socket.assigns.item, socket.assigns.item_id}
      )
    end

    {:noreply, assign(socket, dropdown_open: false)}
  end
end
