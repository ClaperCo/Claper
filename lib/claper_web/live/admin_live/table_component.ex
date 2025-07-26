defmodule ClaperWeb.AdminLive.TableComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <%= for {header, _index} <- Enum.with_index(@headers) do %>
                <th
                  scope="col"
                  class={[
                    "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider",
                    if(@sortable && header.sortable, do: "cursor-pointer hover:bg-gray-100", else: "")
                  ]}
                  phx-click={if @sortable && header.sortable, do: "sort", else: nil}
                  phx-value-field={if @sortable && header.sortable, do: header.field, else: nil}
                  phx-target={@myself}
                >
                  <div class="flex items-center">
                    {if is_binary(header), do: header, else: header.label}
                    <%= if @sortable && header.sortable do %>
                      <%= case @sort_config do %>
                        <% %{field: field, direction: :asc} when field == header.field -> %>
                          <i class="fas fa-sort-up ml-2 text-indigo-500"></i>
                        <% %{field: field, direction: :desc} when field == header.field -> %>
                          <i class="fas fa-sort-down ml-2 text-indigo-500"></i>
                        <% _ -> %>
                          <i class="fas fa-sort ml-2 text-gray-400"></i>
                      <% end %>
                    <% end %>
                  </div>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= if length(@rows) > 0 do %>
              <%= for {row, row_index} <- Enum.with_index(@rows) do %>
                <tr
                  class={[
                    "hover:bg-gray-50",
                    if(@row_click_enabled, do: "cursor-pointer", else: "")
                  ]}
                  phx-click={if @row_click_enabled, do: "row_clicked", else: nil}
                  phx-value-row-index={row_index}
                  phx-target={@myself}
                >
                  <%= for {cell_content, _cell_index} <- Enum.with_index(get_row_cells(row, @headers, @row_func)) do %>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      <%= case cell_content do %>
                        <% {:safe, content} -> %>
                          {raw(content)}
                        <% content when is_binary(content) -> %>
                          {content}
                        <% content -> %>
                          {to_string(content)}
                      <% end %>
                    </td>
                  <% end %>
                </tr>
              <% end %>
            <% else %>
              <tr>
                <td colspan={length(@headers)} class="px-6 py-4 text-center text-sm text-gray-500">
                  <div class="flex flex-col items-center py-8">
                    <%= if @empty_icon do %>
                      <i class={"#{@empty_icon} text-gray-300 text-4xl mb-4"}></i>
                    <% end %>
                    <p class="text-lg font-medium text-gray-900 mb-2">
                      {@empty_title || "No items found"}
                    </p>
                    <p class="text-gray-500">
                      {@empty_message || "There are no items to display."}
                    </p>
                    <%= if @empty_action do %>
                      <div class="mt-4">
                        {render_slot(@empty_action)}
                      </div>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <%= if @pagination do %>
        <div class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
          <div class="flex-1 flex justify-between sm:hidden">
            <%= if @pagination.page_number > 1 do %>
              <button
                type="button"
                phx-click="paginate"
                phx-value-page={@pagination.page_number - 1}
                phx-target={@myself}
                class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Previous
              </button>
            <% else %>
              <span class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-300 bg-gray-50 cursor-not-allowed">
                Previous
              </span>
            <% end %>

            <%= if @pagination.page_number < @pagination.total_pages do %>
              <button
                type="button"
                phx-click="paginate"
                phx-value-page={@pagination.page_number + 1}
                phx-target={@myself}
                class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
              >
                Next
              </button>
            <% else %>
              <span class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-300 bg-gray-50 cursor-not-allowed">
                Next
              </span>
            <% end %>
          </div>

          <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
            <div>
              <p class="text-sm text-gray-700">
                Showing
                <span class="font-medium">
                  {(@pagination.page_number - 1) * @pagination.page_size + 1}
                </span>
                to
                <span class="font-medium">
                  {min(@pagination.page_number * @pagination.page_size, @pagination.total_entries)}
                </span>
                of <span class="font-medium">{@pagination.total_entries}</span>
                results
              </p>
            </div>

            <div>
              <nav
                class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px"
                aria-label="Pagination"
              >
                <%= if @pagination.page_number > 1 do %>
                  <button
                    type="button"
                    phx-click="paginate"
                    phx-value-page={@pagination.page_number - 1}
                    phx-target={@myself}
                    class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                  >
                    <span class="sr-only">Previous</span>
                    <i class="fas fa-chevron-left"></i>
                  </button>
                <% else %>
                  <span class="relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-gray-50 text-sm font-medium text-gray-300 cursor-not-allowed">
                    <span class="sr-only">Previous</span>
                    <i class="fas fa-chevron-left"></i>
                  </span>
                <% end %>

                <%= for page <- get_page_range(@pagination) do %>
                  <%= if page == @pagination.page_number do %>
                    <span class="relative inline-flex items-center px-4 py-2 border border-indigo-500 bg-indigo-50 text-sm font-medium text-indigo-600">
                      {page}
                    </span>
                  <% else %>
                    <button
                      type="button"
                      phx-click="paginate"
                      phx-value-page={page}
                      phx-target={@myself}
                      class="relative inline-flex items-center px-4 py-2 border border-gray-300 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50"
                    >
                      {page}
                    </button>
                  <% end %>
                <% end %>

                <%= if @pagination.page_number < @pagination.total_pages do %>
                  <button
                    type="button"
                    phx-click="paginate"
                    phx-value-page={@pagination.page_number + 1}
                    phx-target={@myself}
                    class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500 hover:bg-gray-50"
                  >
                    <span class="sr-only">Next</span>
                    <i class="fas fa-chevron-right"></i>
                  </button>
                <% else %>
                  <span class="relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-gray-50 text-sm font-medium text-gray-300 cursor-not-allowed">
                    <span class="sr-only">Next</span>
                    <i class="fas fa-chevron-right"></i>
                  </span>
                <% end %>
              </nav>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, sort_config: %{field: nil, direction: :asc})}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:sortable, fn -> false end)
      |> assign_new(:sort_config, fn -> %{field: nil, direction: :asc} end)
      |> assign_new(:row_click_enabled, fn -> false end)
      |> assign_new(:empty_title, fn -> nil end)
      |> assign_new(:empty_message, fn -> nil end)
      |> assign_new(:empty_icon, fn -> nil end)
      |> assign_new(:empty_action, fn -> [] end)
      |> assign_new(:pagination, fn -> nil end)
      |> assign_new(:row_func, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    current_sort = socket.assigns.sort_config

    new_direction =
      if current_sort.field == field and current_sort.direction == :asc do
        :desc
      else
        :asc
      end

    sort_config = %{field: field, direction: new_direction}

    send(self(), {:table_sort_changed, sort_config})
    {:noreply, assign(socket, sort_config: sort_config)}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page_number = String.to_integer(page)
    send(self(), {:table_page_changed, page_number})
    {:noreply, socket}
  end

  def handle_event("row_clicked", %{"row-index" => row_index}, socket) do
    index = String.to_integer(row_index)
    row = Enum.at(socket.assigns.rows, index)
    send(self(), {:table_row_clicked, row, index})
    {:noreply, socket}
  end

  defp get_row_cells(row, headers, nil) do
    # Default behavior: assume row is a list/tuple matching header count
    case row do
      row when is_list(row) -> row
      row when is_tuple(row) -> Tuple.to_list(row)
      _ -> List.duplicate("", length(headers))
    end
  end

  defp get_row_cells(row, _headers, row_func) when is_function(row_func) do
    row_func.(row)
  end

  defp get_page_range(pagination) do
    start_page = max(1, pagination.page_number - 2)
    end_page = min(pagination.total_pages, pagination.page_number + 2)
    start_page..end_page
  end
end
