defmodule ClaperWeb.AdminLive.SearchFilterComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white px-4 py-5 border-b border-gray-200 sm:px-6">
      <div class="-ml-4 -mt-2 flex items-center justify-between flex-wrap sm:flex-nowrap">
        <div class="ml-4 mt-2">
          <form phx-submit="search" phx-target={@myself} class="flex items-center">
            <div class="relative rounded-md shadow-sm">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <i class="fas fa-search text-gray-400"></i>
              </div>
              <input
                type="text"
                name="search"
                value={@search_value || ""}
                class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-10 sm:text-sm border-gray-300 rounded-md"
                placeholder={@search_placeholder || "Search..."}
                phx-debounce="300"
                phx-change="search_change"
                phx-target={@myself}
              />
            </div>

            <%= if @filters && length(@filters) > 0 do %>
              <div class="ml-3 flex space-x-2">
                <%= for filter <- @filters do %>
                  <select
                    name={filter.name}
                    class="block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
                    phx-change="filter_change"
                    phx-target={@myself}
                    phx-value-filter={filter.name}
                  >
                    <option
                      disabled={!@filter_values[filter.name]}
                      selected={!@filter_values[filter.name]}
                    >
                      {filter.label}
                    </option>
                    <%= for {label, value} <- filter.options do %>
                      <option value={value} selected={@filter_values[filter.name] == value}>
                        {label}
                      </option>
                    <% end %>
                  </select>
                <% end %>
              </div>
            <% end %>

            <button
              type="submit"
              class="ml-3 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Search
            </button>

            <%= if @show_clear and (@search_value || has_active_filters?(@filter_values)) do %>
              <button
                type="button"
                phx-click="clear_all"
                phx-target={@myself}
                class="ml-2 inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
              >
                Clear
              </button>
            <% end %>
          </form>
        </div>

        <div class="ml-4 mt-2 flex-shrink-0">
          <%= if @export_csv_enabled do %>
            <button
              type="button"
              phx-click="export_csv"
              phx-target={@myself}
              class="relative inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-green-500"
            >
              <i class="fas fa-file-csv mr-2"></i> Export CSV
            </button>
          <% end %>

          <%= if @new_path do %>
            <.link
              navigate={@new_path}
              class="ml-3 relative inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <i class="fas fa-plus mr-2"></i>
              {@new_label || "New"}
            </.link>
          <% end %>

          <%= if @custom_actions do %>
            {render_slot(@custom_actions)}
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, search_value: "", filter_values: %{})}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:search_placeholder, fn -> "Search..." end)
      |> assign_new(:filters, fn -> [] end)
      |> assign_new(:filter_values, fn -> %{} end)
      |> assign_new(:search_value, fn -> "" end)
      |> assign_new(:show_clear, fn -> true end)
      |> assign_new(:export_csv_enabled, fn -> false end)
      |> assign_new(:new_path, fn -> nil end)
      |> assign_new(:new_label, fn -> "New" end)
      |> assign_new(:custom_actions, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_value}, socket) do
    send(
      self(),
      {:search_filter_changed, %{search: search_value, filters: socket.assigns.filter_values}}
    )

    {:noreply, assign(socket, search_value: search_value)}
  end

  def handle_event("search_change", %{"search" => search_value}, socket) do
    send(
      self(),
      {:search_filter_changed, %{search: search_value, filters: socket.assigns.filter_values}}
    )

    {:noreply, assign(socket, search_value: search_value)}
  end

  def handle_event("filter_change", %{"filter" => filter_name, "value" => filter_value}, socket) do
    filter_values = Map.put(socket.assigns.filter_values, filter_name, filter_value)

    send(
      self(),
      {:search_filter_changed, %{search: socket.assigns.search_value, filters: filter_values}}
    )

    {:noreply, assign(socket, filter_values: filter_values)}
  end

  def handle_event("clear_all", _params, socket) do
    send(self(), {:search_filter_changed, %{search: "", filters: %{}}})
    {:noreply, assign(socket, search_value: "", filter_values: %{})}
  end

  def handle_event("export_csv", _params, socket) do
    send(
      self(),
      {:export_csv_requested,
       %{search: socket.assigns.search_value, filters: socket.assigns.filter_values}}
    )

    {:noreply, socket}
  end

  defp has_active_filters?(filter_values) do
    Enum.any?(filter_values, fn {_key, value} -> value != nil and value != "" end)
  end
end
