defmodule ClaperWeb.AdminLive.FormFieldComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @width_class, do: @width_class, else: "sm:col-span-6"}>
      <%= label @form, @field, @label, class: "block text-sm font-medium text-gray-700" %>
      <div class="mt-1">
        <%= case @type do %>
          <% "text" -> %>
            <%= text_input @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               placeholder: @placeholder, 
               required: @required] ++ @extra_attrs %>
          
          <% "email" -> %>
            <%= email_input @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               placeholder: @placeholder, 
               required: @required] ++ @extra_attrs %>
          
          <% "password" -> %>
            <div class="relative">
              <%= password_input @form, @field, 
                [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md pr-10", 
                 placeholder: @placeholder, 
                 required: @required,
                 id: "password-field-#{@field}"] ++ @extra_attrs %>
              <button
                type="button"
                class="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-400 hover:text-gray-600"
                phx-click={toggle_password_visibility("password-field-#{@field}")}
              >
                <i class="fas fa-eye"></i>
              </button>
            </div>
          
          <% "textarea" -> %>
            <%= textarea @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               placeholder: @placeholder, 
               required: @required,
               rows: @rows] ++ @extra_attrs %>
          
          <% "select" -> %>
            <%= select @form, @field, @select_options, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               prompt: @prompt || "Select an option", 
               required: @required] ++ @extra_attrs %>
          
          <% "checkbox" -> %>
            <div class="flex items-center">
              <%= checkbox @form, @field, 
                [class: "h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"] ++ @extra_attrs %>
              <span class="ml-2 text-sm text-gray-600"><%= @checkbox_label || @label %></span>
            </div>
          
          <% "date" -> %>
            <%= date_input @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               required: @required] ++ @extra_attrs %>
          
          <% "datetime" -> %>
            <%= datetime_local_input @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               required: @required] ++ @extra_attrs %>
          
          <% "file" -> %>
            <div class="flex items-center">
              <label class="cursor-pointer bg-white py-2 px-3 border border-gray-300 rounded-md shadow-sm text-sm leading-4 font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                <span>Choose file</span>
                <%= file_input @form, @field, 
                  [class: "sr-only", 
                   required: @required,
                   phx_change: "file_selected",
                   phx_target: @myself] ++ @extra_attrs %>
              </label>
              <span class="ml-3 text-sm text-gray-500" id={"file-name-#{@field}"}>
                <%= if @selected_file, do: @selected_file, else: "No file chosen" %>
              </span>
            </div>
          
          <% _ -> %>
            <%= text_input @form, @field, 
              [class: "shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md", 
               placeholder: @placeholder, 
               required: @required] ++ @extra_attrs %>
        <% end %>
        
        <%= error_tag @form, @field %>
        
        <%= if @description do %>
          <p class="mt-2 text-sm text-gray-500"><%= @description %></p>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, selected_file: nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket = 
      socket
      |> assign(assigns)
      |> assign_new(:placeholder, fn -> "" end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:width_class, fn -> nil end)
      |> assign_new(:checkbox_label, fn -> nil end)
      |> assign_new(:prompt, fn -> nil end)
      |> assign_new(:select_options, fn -> [] end)
      |> assign_new(:rows, fn -> 3 end)
      |> assign_new(:extra_attrs, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def handle_event("file_selected", %{"_target" => [_field_name]}, socket) do
    {:noreply, assign(socket, selected_file: "File selected")}
  end

  defp toggle_password_visibility(field_id) do
    %Phoenix.LiveView.JS{}
    |> Phoenix.LiveView.JS.dispatch("toggle-password", to: "##{field_id}")
  end
end