defmodule ClaperWeb.AdminLive.EventLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Events
  alias Claper.Accounts

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
            label={gettext("Name")}
            placeholder={gettext("Enter event name")}
            required={true}
            width_class="sm:col-span-6"
            description={gettext("A unique name for this event")}
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-code"
            form={@form}
            field={:code}
            type="text"
            label={gettext("Code")}
            placeholder={gettext("Enter event code")}
            required={true}
            width_class="sm:col-span-3"
            field_class="uppercase"
            description={gettext("A unique code for participants to join this event")}
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-started-at"
            form={@form}
            field={:started_at}
            type="datetime"
            label={gettext("Started At")}
            required={true}
            width_class="sm:col-span-3"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="event-expired-at"
            form={@form}
            field={:expired_at}
            type="datetime"
            label={gettext("Expired At")}
            required={false}
            width_class="sm:col-span-3"
            description={gettext("When this event expires (optional)")}
          />

          <.live_component
            module={ClaperWeb.AdminLive.SearchableSelectComponent}
            id="event-user-id"
            form={@form}
            field={:user_id}
            label={gettext("Assigned User")}
            options={@user_options}
            placeholder={gettext("Search for a user...")}
            required={true}
            width_class="sm:col-span-6"
            description={gettext("The user who owns this event (required)")}
          />
        </div>

        <div class="pt-6">
          <div class="flex justify-end gap-3">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
              {gettext("Cancel")}
            </button>
            <button type="submit" phx-disable-with={gettext("Saving...")} class="btn btn-primary">
              {if @action == :new, do: gettext("Create Event"), else: gettext("Update Event")}
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

    user_options =
      Accounts.list_users()
      |> Enum.map(&{"#{&1.email}", &1.id})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:user_options, user_options)
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
         |> put_flash(:info, gettext("Event updated successfully"))
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
         |> put_flash(:info, gettext("Event created successfully"))
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
