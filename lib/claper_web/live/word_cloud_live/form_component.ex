defmodule ClaperWeb.WordCloudLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.WordClouds

  @impl true
  def update(%{word_cloud: word_cloud} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, WordClouds.change_word_cloud(word_cloud))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case WordClouds.get_word_cloud_for_event(id, socket.assigns.presentation_file.event_id) do
      nil ->
        {:noreply, socket}

      word_cloud ->
        {:ok, _} = WordClouds.delete_word_cloud(socket.assigns.event_uuid, word_cloud)
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  @impl true
  def handle_event("validate", %{"word_cloud" => word_cloud_params}, socket) do
    changeset =
      socket.assigns.word_cloud
      |> WordClouds.change_word_cloud(word_cloud_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"word_cloud" => word_cloud_params}, socket) do
    save_word_cloud(socket, socket.assigns.live_action, word_cloud_params)
  end

  # Slide, file and state are set by the server when a cloud is created, moved
  # or switched on, never by the editor's params.
  defp save_word_cloud(socket, :edit, word_cloud_params) do
    case WordClouds.update_word_cloud(
           socket.assigns.event_uuid,
           socket.assigns.word_cloud,
           Map.take(word_cloud_params, ["title", "max_entries", "show_results"])
         ) do
      {:ok, _word_cloud} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_word_cloud(socket, :new, word_cloud_params) do
    case WordClouds.create_word_cloud(
           word_cloud_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, _word_cloud} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end
end
