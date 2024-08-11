defmodule ClaperWeb.EmbedLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Embeds

  @impl true
  def update(%{embed: embed} = assigns, socket) do
    changeset = Embeds.change_embed(embed)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:embeds, list_embeds(assigns))
     |> assign(:providers, [
       {"YouTube", "youtube"},
       {"Vimeo", "vimeo"},
       {"Canva", "canva"},
       {"Google Slides", "googleslides"},
       {"Custom (iframe)", "custom"}
     ])
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    embed = Embeds.get_embed!(id)
    {:ok, _} = Embeds.delete_embed(socket.assigns.event_uuid, embed)

    {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
  end

  @impl true
  def handle_event("validate", %{"embed" => embed_params}, socket) do
    changeset =
      socket.assigns.embed
      |> Embeds.change_embed(embed_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"embed" => embed_params}, socket) do
    save_embed(socket, socket.assigns.live_action, embed_params)
  end

  defp save_embed(socket, :edit, embed_params) do
    case Embeds.update_embed(
           socket.assigns.event_uuid,
           socket.assigns.embed,
           embed_params
         ) do
      {:ok, _embed} ->
        {:noreply,
         socket
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_embed(socket, :new, embed_params) do
    case Embeds.create_embed(
           embed_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, embed} ->
        {:noreply,
         socket
         |> maybe_change_current_embed(embed)
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_embed(socket, %{enabled: true} = embed) do
    embed = Embeds.get_embed!(embed.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_embed, embed}
    )

    socket
  end

  defp maybe_change_current_embed(socket, _), do: socket

  defp list_embeds(assigns) do
    Embeds.list_embeds(assigns.presentation_file.id)
  end
end
