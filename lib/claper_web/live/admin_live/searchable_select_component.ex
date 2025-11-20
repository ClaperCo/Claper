defmodule ClaperWeb.AdminLive.SearchableSelectComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @width_class, do: @width_class, else: "sm:col-span-6"}>
      <div class="form-control w-full">
        <label class="label">
          <span class="label-text">{@label}</span>
        </label>

        <div class="dropdown dropdown-bottom w-full">
          <input
            type="text"
            value={@search_term}
            placeholder={@placeholder}
            class="input input-bordered w-full"
            phx-keyup="search"
            phx-focus="open_dropdown"
            phx-target={@myself}
            phx-debounce="300"
            autocomplete="off"
            tabindex="0"
          />

          <input
            type="hidden"
            name={"#{@form.name}[#{@field}]"}
            value={@selected_value || ""}
            id={"#{@form.name}_#{@field}"}
          />

          <%= if @show_dropdown and length(@filtered_options) > 0 do %>
            <ul
              tabindex="0"
              class="dropdown-content menu bg-base-100 rounded-box z-[1] w-full p-2 shadow"
              phx-click-away="close_dropdown"
              phx-target={@myself}
            >
              <%= for {label, value} <- @filtered_options do %>
                <li class="w-full">
                  <a
                    class={if to_string(value) == to_string(@selected_value), do: "active", else: ""}
                    phx-click="select_option"
                    phx-value-value={value}
                    phx-value-label={label}
                    phx-target={@myself}
                  >
                    {label}
                  </a>
                </li>
              <% end %>
            </ul>
          <% end %>
        </div>

        <label class="label">
          {error_tag(@form, @field)}
          <%= if @description do %>
            <span class="label-text-alt">{@description}</span>
          <% end %>
        </label>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_dropdown, false)
     |> assign(:search_term, "")
     |> assign(:filtered_options, [])
     |> assign(:selected_value, nil)
     |> assign(:display_value, "")}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:placeholder, fn -> gettext("Select...") end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:width_class, fn -> nil end)
      |> assign_new(:options, fn -> [] end)
      |> update_filtered_options()
      |> update_display_value()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"value" => search_term}, socket) do
    socket =
      socket
      |> assign(:search_term, search_term)
      |> assign(:show_dropdown, true)
      |> update_filtered_options()

    {:noreply, socket}
  end

  def handle_event("select_option", %{"value" => value, "label" => label}, socket) do
    socket =
      socket
      |> assign(:selected_value, value)
      |> assign(:display_value, label)
      |> assign(:show_dropdown, false)
      |> assign(:search_term, label)

    {:noreply, socket}
  end

  def handle_event("open_dropdown", _params, socket) do
    socket =
      socket
      |> assign(:show_dropdown, true)
      |> update_filtered_options()

    {:noreply, socket}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  defp update_filtered_options(socket) do
    search_term = String.downcase(socket.assigns[:search_term] || "")

    filtered =
      if search_term == "" do
        socket.assigns.options
      else
        Enum.filter(socket.assigns.options, fn {label, _value} ->
          String.contains?(String.downcase(label), search_term)
        end)
      end

    assign(socket, :filtered_options, filtered)
  end

  defp update_display_value(socket) do
    current_value = get_field_value(socket.assigns.form, socket.assigns.field)
    display_value = find_display_value(current_value, socket.assigns.options)

    socket
    |> assign(:selected_value, current_value)
    |> assign(:display_value, display_value)
    |> assign(:search_term, display_value)
  end

  defp find_display_value(nil, _options), do: ""

  defp find_display_value(current_value, options) do
    case Enum.find(options, fn {_label, value} ->
           to_string(value) == to_string(current_value)
         end) do
      {label, _value} -> label
      nil -> ""
    end
  end

  defp get_field_value(form, field) do
    Map.get(form.data, field) || Map.get(form.params, to_string(field))
  end
end
