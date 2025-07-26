defmodule ClaperWeb.AdminLive.EventLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Events

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="event-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="grid grid-cols-6 gap-6">
          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-name"
            form={@form}
            field={:name}
            type="text"
            label="Name"
            placeholder="Enter event name"
            required={true}
            width_class="sm:col-span-6"
            description="A unique name for this event"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-code"
            form={@form}
            field={:code}
            type="text"
            label="Code"
            placeholder="Enter event code"
            required={true}
            width_class="sm:col-span-3"
            description="A unique code for participants to join this event"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-started-at"
            form={@form}
            field={:started_at}
            type="datetime"
            label="Started At"
            required={true}
            width_class="sm:col-span-3"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-expired-at"
            form={@form}
            field={:expired_at}
            type="datetime"
            label="Expired At"
            required={false}
            width_class="sm:col-span-3"
            description="When this event expires (optional)"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-audience-peak"
            form={@form}
            field={:audience_peak}
            type="text"
            label="Audience Peak"
            placeholder="Enter peak audience count"
            required={false}
            width_class="sm:col-span-3"
            extra_attrs={[min: "0", pattern: "[0-9]*"]}
            description="Peak number of participants (optional)"
          />
        </div>

        <div class="pt-6">
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </button>
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              {if @action == :new, do: "Create Event", else: "Update Event"}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{event: event} = assigns, socket) do
    changeset = Events.change_event(event)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"event" => event_params}, socket) do
    save_event(socket, socket.assigns.action, event_params)
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.navigate)}
  end

  defp save_event(socket, :edit, event_params) do
    case Events.update_event(socket.assigns.event, event_params) do
      {:ok, event} ->
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> put_flash(:info, "Event updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_event(socket, :new, event_params) do
    case Events.create_event(event_params) do
      {:ok, event} ->
        notify_parent({:saved, event})

        {:noreply,
         socket
         |> put_flash(:info, "Event created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
