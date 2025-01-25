defmodule ClaperWeb.StoryLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Stories

  @impl true
  def update(%{story: story} = assigns, socket) do
    changeset = Stories.change_story(story)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:stories, list_stories(assigns))
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    story = Stories.get_story!(id)
    {:ok, _} = Stories.delete_story(socket.assigns.event_uuid, story)

    {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
  end

  @impl true
  def handle_event("validate", %{"story" => story_params}, socket) do
    changeset =
      socket.assigns.story
      |> Stories.change_story(story_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"story" => story_params}, socket) do
    save_story(socket, socket.assigns.live_action, story_params)
  end

  @impl true
  def handle_event("add_opt", _params, %{assigns: %{changeset: changeset}} = socket) do
    {:noreply, assign(socket, :changeset, changeset |> Stories.add_story_opt())}
  end

  @impl true
  def handle_event(
        "remove_opt",
        %{"opt" => opt} = _params,
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {opt, _} = Integer.parse(opt)

    story_opt = Enum.at(Ecto.Changeset.get_field(changeset, :story_opts), opt)

    {:noreply, assign(socket, :changeset, changeset |> Stories.remove_story_opt(story_opt))}
  end

  defp save_story(socket, :edit, story_params) do
    case Stories.update_story(
           socket.assigns.event_uuid,
           socket.assigns.story,
           story_params
         ) do
      {:ok, _story} ->
        {:noreply,
         socket
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_story(socket, :new, story_params) do
    case Stories.create_story(
           story_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, story} ->
        {:noreply,
         socket
         |> maybe_change_current_story(story)
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_story(socket, %{enabled: true} = story) do
    story = Stories.get_story!(story.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_story, story}
    )

    socket
  end

  defp maybe_change_current_story(socket, _), do: socket

  defp list_stories(assigns) do
    Stories.list_stories(assigns.presentation_file.id)
  end
end
