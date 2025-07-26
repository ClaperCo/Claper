defmodule ClaperWeb.AdminLive.ModalComponent do
  use ClaperWeb, :live_component
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed z-50 inset-0 overflow-y-auto"
      aria-labelledby={"#{@id}-title"}
      role="dialog"
      aria-modal="true"
      phx-remove={hide_modal(@id)}
      style={if @show, do: "", else: "display: none;"}
    >
      <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
        <!-- Background overlay -->
        <div
          class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"
          aria-hidden="true"
          phx-click="hide"
          phx-target={@myself}
        >
        </div>
        
    <!-- Trick browser into centering modal contents -->
        <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">
          &#8203;
        </span>
        
    <!-- Modal panel -->
        <div class={[
          "inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle",
          @size_class
        ]}>
          <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
            <div class="sm:flex sm:items-start">
              <%= if @icon do %>
                <div class={[
                  "mx-auto flex-shrink-0 flex items-center justify-center h-12 w-12 rounded-full sm:mx-0 sm:h-10 sm:w-10",
                  @icon_bg_class
                ]}>
                  <i class={"fas #{@icon} #{@icon_text_class}"}></i>
                </div>
              <% end %>

              <div class={[
                "mt-3 text-center sm:mt-0 sm:text-left",
                if(@icon, do: "sm:ml-4", else: "w-full")
              ]}>
                <h3 class="text-lg leading-6 font-medium text-gray-900" id={"#{@id}-title"}>
                  {@title}
                </h3>
                <div class="mt-2">
                  <%= if @description do %>
                    <p class="text-sm text-gray-500">
                      {@description}
                    </p>
                  <% end %>

                  <%= if @content do %>
                    <div class="mt-4">
                      {render_slot(@content)}
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
            <%= if @confirm_action do %>
              <button
                type="button"
                phx-click="confirm"
                phx-target={@myself}
                class={[
                  "w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 text-base font-medium text-white focus:outline-none focus:ring-2 focus:ring-offset-2 sm:ml-3 sm:w-auto sm:text-sm",
                  @confirm_class
                ]}
              >
                {@confirm_action}
              </button>
            <% end %>

            <%= if @cancel_action do %>
              <button
                type="button"
                phx-click="hide"
                phx-target={@myself}
                class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
              >
                {@cancel_action}
              </button>
            <% end %>

            <%= if @custom_actions do %>
              {render_slot(@custom_actions)}
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, show: false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show, fn -> false end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:icon_bg_class, fn -> "bg-red-100" end)
      |> assign_new(:icon_text_class, fn -> "text-red-600" end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:content, fn -> [] end)
      |> assign_new(:confirm_action, fn -> nil end)
      |> assign_new(:confirm_class, fn -> "bg-red-600 hover:bg-red-700 focus:ring-red-500" end)
      |> assign_new(:cancel_action, fn -> "Cancel" end)
      |> assign_new(:custom_actions, fn -> [] end)
      |> assign_new(:size_class, fn -> "sm:max-w-lg sm:w-full" end)

    {:ok, socket}
  end

  @impl true
  def handle_event("hide", _params, socket) do
    send(self(), {:modal_cancelled, socket.assigns.id})
    {:noreply, assign(socket, show: false)}
  end

  def handle_event("confirm", _params, socket) do
    send(self(), {:modal_confirmed, socket.assigns.id})
    {:noreply, assign(socket, show: false)}
  end

  # Public API for controlling the modal
  def show_modal(js \\ %JS{}, modal_id) do
    js
    |> JS.show(to: "##{modal_id}")
    |> JS.add_class("animate-fade-in", to: "##{modal_id}")
  end

  def hide_modal(js \\ %JS{}, modal_id) do
    js
    |> JS.add_class("animate-fade-out", to: "##{modal_id}")
    |> JS.hide(to: "##{modal_id}", transition: "animate-fade-out", time: 200)
  end

  # Preset configurations for common modal types
  def delete_modal_config(title, description) do
    %{
      icon: "fa-exclamation-triangle",
      icon_bg_class: "bg-red-100",
      icon_text_class: "text-red-600",
      title: title,
      description: description,
      confirm_action: "Delete",
      confirm_class: "bg-red-600 hover:bg-red-700 focus:ring-red-500",
      cancel_action: "Cancel"
    }
  end

  def warning_modal_config(title, description) do
    %{
      icon: "fa-exclamation-triangle",
      icon_bg_class: "bg-yellow-100",
      icon_text_class: "text-yellow-600",
      title: title,
      description: description,
      confirm_action: "Continue",
      confirm_class: "bg-yellow-600 hover:bg-yellow-700 focus:ring-yellow-500",
      cancel_action: "Cancel"
    }
  end

  def info_modal_config(title, description) do
    %{
      icon: "fa-info-circle",
      icon_bg_class: "bg-blue-100",
      icon_text_class: "text-blue-600",
      title: title,
      description: description,
      confirm_action: "OK",
      confirm_class: "bg-blue-600 hover:bg-blue-700 focus:ring-blue-500",
      cancel_action: nil
    }
  end
end
