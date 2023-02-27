defmodule ClaperWeb.FormLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Forms

  @impl true
  def update(%{form: form} = assigns, socket) do
    changeset = Forms.change_form(form)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:forms, list_forms(assigns))
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    form = Forms.get_form!(id)
    {:ok, _} = Forms.delete_form(socket.assigns.event_uuid, form)

    {:noreply, socket |> push_redirect(to: socket.assigns.return_to)}
  end

  @impl true
  def handle_event("validate", %{"form" => form_params}, socket) do
    changeset =
      socket.assigns.form
      |> Forms.change_form(form_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"form" => form_params}, socket) do
    save_form(socket, socket.assigns.live_action, form_params)
  end

  @impl true
  def handle_event("add_field", _params, %{assigns: %{changeset: changeset}} = socket) do
    {:noreply, assign(socket, :changeset, changeset |> Forms.add_form_field())}
  end

  @impl true
  def handle_event(
        "remove_field",
        %{"field" => field} = _params,
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {field, _} = Integer.parse(field)

    form_field = Enum.at(Ecto.Changeset.get_field(changeset, :fields), field)

    {:noreply, assign(socket, :changeset, changeset |> Forms.remove_form_field(form_field))}
  end

  defp save_form(socket, :edit, form_params) do
    case Forms.update_form(
           socket.assigns.event_uuid,
           socket.assigns.form,
           form_params
         ) do
      {:ok, _form} ->
        {:noreply,
         socket
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_form(socket, :new, form_params) do
    case Forms.create_form(
           form_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> maybe_enable(socket)
         ) do
      {:ok, form} ->
        {:noreply,
         socket
         |> maybe_change_current_form(form)
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_form(socket, %{enabled: true} = form) do
    form = Forms.get_form!(form.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_form, form}
    )

    socket
  end

  defp maybe_change_current_form(socket, _), do: socket

  defp maybe_enable(form_params, socket) do
    has_current_form =
      socket.assigns.forms
      |> Enum.filter(fn f -> f.position == socket.assigns.position && f.enabled == true end)
      |> Enum.count() > 0

    form_params |> Map.put("enabled", !has_current_form)
  end

  defp list_forms(assigns) do
    Forms.list_forms(assigns.presentation_file.id)
  end
end
