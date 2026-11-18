defmodule ClaperWeb.ScaleLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Scales

  @impl true
  def update(%{scale: scale} = assigns, socket) do
    answered = Scales.answered?(scale)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:answered, answered)
     |> assign(:changeset, Scales.change_scale(scale, %{}, answered: answered))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Scales.get_scale_for_event(id, socket.assigns.presentation_file.event_id) do
      nil ->
        {:noreply, socket}

      scale ->
        {:ok, _} = Scales.delete_scale(socket.assigns.event_uuid, scale)
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  @impl true
  def handle_event("validate", %{"scale" => scale_params}, socket) do
    changeset =
      socket.assigns.scale
      |> Scales.change_scale(scale_params, answered: socket.assigns.answered)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"scale" => scale_params}, socket) do
    save_scale(socket, socket.assigns.live_action, scale_params)
  end

  @editable ~w(title min_value max_value step min_label max_label show_results)

  # Slide, file and state are set by the server when a slider is created, moved
  # or switched on, never by the editor's params.
  defp save_scale(socket, :edit, scale_params) do
    case Scales.update_scale(
           socket.assigns.event_uuid,
           socket.assigns.scale,
           Map.take(scale_params, @editable)
         ) do
      {:ok, _scale} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_scale(socket, :new, scale_params) do
    case scale_params
         |> Map.take(@editable)
         |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
         |> Map.put("position", socket.assigns.position)
         |> Map.put("enabled", false)
         |> Scales.create_scale() do
      {:ok, _scale} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
