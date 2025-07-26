defmodule ClaperWeb.AdminLive.ComponentsDemoLive do
  use ClaperWeb, :live_view
  import ClaperWeb.Components, only: [input: 1, button: 1, ui_label: 1]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:email, "")
     |> assign(:name, "")
     |> assign(:filled_input, "Hey bonjour")
     |> assign(:loading, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 p-8">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-3xl font-bold text-gray-900 mb-8">Component Library Demo</h1>
        
    <!-- Input Components Section -->
        <section class="mb-12">
          <h2 class="text-2xl font-semibold text-gray-800 mb-6">Input Components</h2>

          <div class="bg-white rounded-lg shadow-sm p-6 space-y-6">
            <!-- Empty Input State -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Empty Input</h3>
              <.input
                id="empty-input"
                name="email"
                type="email"
                value={@email}
                class="my-2"
                placeholder="Enter your email"
                phx-change="update_email"
              />
            </div>
            
    <!-- Focused Input State (with label) -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Input with Label</h3>
              <.input
                id="name-input"
                name="name"
                label="Your Name"
                value={@name}
                placeholder="Hey"
                phx-change="update_name"
              />
            </div>
            
    <!-- Filled Input State -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Filled Input</h3>
              <.input
                id="filled-input"
                name="message"
                value={@filled_input}
                placeholder="Type something..."
                phx-change="update_filled"
              />
            </div>
            
    <!-- Input with Error -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Input with Error</h3>
              <.input
                id="error-input"
                name="required"
                label="Required Field"
                value=""
                placeholder="This field is required"
                errors={["This field cannot be empty"]}
                required={true}
              />
            </div>
            
    <!-- Disabled Input -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Disabled Input</h3>
              <.input id="disabled-input" name="disabled" value="Cannot edit this" disabled={true} />
            </div>
          </div>
        </section>
        
    <!-- Button Components Section -->
        <section class="mb-12">
          <h2 class="text-2xl font-semibold text-gray-800 mb-6">Button Components</h2>

          <div class="bg-white rounded-lg shadow-sm p-6">
            <!-- Button Variants -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-700 mb-3">Button Variants</h3>
              <div class="flex flex-wrap gap-4">
                <.button variant="primary">Primary Button</.button>
                <.button variant="secondary">Secondary Button</.button>
                <.button variant="outline">Outline Button</.button>
                <.button variant="danger">Danger Button</.button>
                <.button variant="emphasis">Emphasis Button</.button>
              </div>
            </div>
            
    <!-- Button Sizes -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-700 mb-3">Button Sizes</h3>
              <div class="flex items-center gap-4">
                <.button size="small">Small</.button>
                <.button size="base">Base</.button>
              </div>
            </div>
            
    <!-- Button States -->
            <div class="mb-6">
              <h3 class="text-lg font-medium text-gray-700 mb-3">Button States</h3>
              <div class="flex gap-4">
                <.button disabled={true}>Disabled</.button>
                <.button loading={@loading} phx-click="toggle_loading">
                  {if @loading, do: "Loading...", else: "Click to Load"}
                </.button>
              </div>
            </div>
            
    <!-- Form Submit Button -->
            <div>
              <h3 class="text-lg font-medium text-gray-700 mb-3">Form Submit Button</h3>
              <form phx-submit="submit_form" class="flex items-end gap-4">
                <.input
                  id="submit-input"
                  name="submit_value"
                  placeholder="Type and submit..."
                  class="flex-1"
                />
                <.button type="submit" variant="primary">Submit</.button>
              </form>
            </div>
          </div>
        </section>
        
    <!-- Label Component Section -->
        <section class="mb-12">
          <h2 class="text-2xl font-semibold text-gray-800 mb-6">Label Components</h2>

          <div class="bg-white rounded-lg shadow-sm p-6 space-y-4">
            <div>
              <.ui_label for="demo-1">Regular Label</.ui_label>
              <input type="text" id="demo-1" class="mt-1 block w-full rounded-md border-gray-300" />
            </div>

            <div>
              <.ui_label for="demo-2" required={true}>Required Label</.ui_label>
              <input type="text" id="demo-2" class="mt-1 block w-full rounded-md border-gray-300" />
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_email", %{"email" => email}, socket) do
    {:noreply, assign(socket, :email, email)}
  end

  def handle_event("update_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, :name, name)}
  end

  def handle_event("update_filled", %{"message" => message}, socket) do
    {:noreply, assign(socket, :filled_input, message)}
  end

  def handle_event("toggle_loading", _params, socket) do
    {:noreply, assign(socket, :loading, !socket.assigns.loading)}
  end

  def handle_event("submit_form", %{"submit_value" => value}, socket) do
    {:noreply, put_flash(socket, :info, "Form submitted with: #{value}")}
  end
end
