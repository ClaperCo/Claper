defmodule ClaperWeb.AdminLive.EventLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Events
  alias Claper.Events.Event
  alias ClaperWeb.Validators.AdminFormValidator
  alias ClaperWeb.Component.Input

  @impl true
  def update(%{event: event} = assigns, socket) do
    changeset = Events.change_event(event)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    save_event(socket, socket.assigns.action, event_params)
  end

  defp save_event(socket, :edit, event_params) do
    case Events.update_event(socket.assigns.event, event_params) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "event")
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_event(socket, :new, event_params) do
    case Events.create_event(event_params) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "event")
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2"><%= @title %></h2>
      <p class="text-gray-600 mb-6">
        <%= if @action == :edit do %>
          Edit event details
        <% else %>
          Create a new event
        <% end %>
      </p>

      <%= form_for @changeset, "#",
        [id: "event-form", phx_target: @myself, phx_change: "validate", phx_submit: "save"], fn form -> %>
        <div class="space-y-6">
          <Input.text form={form} key={:name} name="Name" required={true} />
          <Input.code form={form} key={:code} name="Code" required={true} />
          <Input.text form={form} key={:theme} name="Theme" />
          <Input.text form={form} key={:logo_url} name="Logo URL" />
          <Input.date form={form} key={:started_at} name="Start Date" />
          <Input.date form={form} key={:expired_at} name="Expiry Date" />
          <Input.text form={form} key={:password} name="Password" />
          <Input.text form={form} key={:qr_code_logo_url} name="QR Code Logo URL" />
          <Input.textarea form={form} key={:custom_css} name="Custom CSS" />
          <Input.textarea form={form} key={:custom_js} name="Custom JavaScript" />
          <Input.text form={form} key={:audience_peak} name="Audience Peak" />
          
          <div class="flex justify-end mt-6">
            <button type="submit" phx-disable-with="Saving..." class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Save Event
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
