defmodule ClaperWeb.TranscriptionLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Transcriptions

  defp languages do
    [
      {gettext("Auto-detect"), ""},
      {gettext("English"), "en"},
      {gettext("French"), "fr"},
      {gettext("German"), "de"},
      {gettext("Spanish"), "es"},
      {gettext("Italian"), "it"},
      {gettext("Portuguese"), "pt"},
      {gettext("Dutch"), "nl"},
      {gettext("Polish"), "pl"},
      {gettext("Russian"), "ru"},
      {gettext("Japanese"), "ja"},
      {gettext("Chinese"), "zh"},
      {gettext("Korean"), "ko"},
      {gettext("Arabic"), "ar"},
      {gettext("Hindi"), "hi"},
      {gettext("Turkish"), "tr"},
      {gettext("Swedish"), "sv"},
      {gettext("Norwegian"), "no"},
      {gettext("Danish"), "da"},
      {gettext("Finnish"), "fi"}
    ]
  end

  @impl true
  def update(%{transcription_config: config} = assigns, socket) do
    changeset = Transcriptions.change_transcription_config(config)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:languages, languages())
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"transcription_config" => params}, socket) do
    changeset =
      socket.assigns.transcription_config
      |> Transcriptions.change_transcription_config(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"transcription_config" => params}, socket) do
    save_config(socket, socket.assigns.live_action, params)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Transcriptions.get_transcription_config_for_event(
           id,
           socket.assigns.presentation_file.event_id
         ) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Resource not found"))
         |> push_navigate(to: socket.assigns.return_to)}

      config ->
        {:ok, _} = Transcriptions.delete_transcription_config(socket.assigns.event_uuid, config)

        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  defp save_config(socket, :edit, params) do
    case Transcriptions.update_transcription_config(
           socket.assigns.event_uuid,
           socket.assigns.transcription_config,
           normalize_language(params)
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
         ) do
      {:ok, _config} ->
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_config(socket, :new, params) do
    case Transcriptions.create_transcription_config(
           normalize_language(params)
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("enabled", false)
         ) do
      {:ok, config} ->
        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{socket.assigns.event_uuid}",
          {:transcription_config_created, config}
        )

        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp normalize_language(%{"language" => ""} = params), do: Map.put(params, "language", nil)
  defp normalize_language(params), do: params
end
