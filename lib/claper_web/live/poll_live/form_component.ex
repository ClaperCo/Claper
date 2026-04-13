defmodule ClaperWeb.PollLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Polls

  @impl true
  def update(%{poll: poll} = assigns, socket) do
    changeset = build_changeset(assigns, poll)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:dark, fn -> false end)
     |> assign(:polls, list_polls(assigns))
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Polls.get_poll_for_event(id, socket.assigns.presentation_file.event_id) do
      nil ->
        {:noreply, socket}

      poll ->
        {:ok, _} = Polls.delete_poll(socket.assigns.event_uuid, poll)
        {:noreply, socket |> push_navigate(to: socket.assigns.return_to)}
    end
  end

  @impl true
  def handle_event("validate", %{"poll" => poll_params}, socket) do
    changeset =
      socket
      |> build_poll_changeset(poll_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"poll" => poll_params}, socket) do
    save_poll(socket, socket.assigns.live_action, poll_params)
  end

  @impl true
  def handle_event("add_opt", _params, %{assigns: %{changeset: changeset}} = socket) do
    {:noreply, assign(socket, :changeset, changeset |> Polls.add_poll_opt())}
  end

  @impl true
  def handle_event(
        "remove_opt",
        %{"opt" => opt} = _params,
        %{assigns: %{changeset: changeset}} = socket
      ) do
    {opt, _} = Integer.parse(opt)

    {:noreply, assign(socket, :changeset, changeset |> Polls.remove_poll_opt(opt))}
  end

  defp save_poll(socket, :edit, poll_params) do
    case Polls.update_poll(
           socket.assigns.event_uuid,
           socket.assigns.poll,
           poll_params
         ) do
      {:ok, _poll} ->
        {:noreply,
         socket
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_poll(socket, :new, poll_params) do
    case Polls.create_poll(
           poll_params
           |> Map.put("presentation_file_id", socket.assigns.presentation_file.id)
           |> Map.put("position", socket.assigns.position)
           |> Map.put("enabled", false)
         ) do
      {:ok, poll} ->
        {:noreply,
         socket
         |> maybe_change_current_poll(poll)
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp maybe_change_current_poll(socket, %{enabled: true} = poll) do
    poll = Polls.get_poll!(poll.id)

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{socket.assigns.event_uuid}",
      {:current_poll, poll}
    )

    socket
  end

  defp maybe_change_current_poll(socket, _), do: socket

  defp build_changeset(
         %{live_action: :new, presentation_file: presentation_file, position: position},
         _poll
       ) do
    %Polls.Poll{}
    |> Polls.change_poll(%{
      "enabled" => false,
      "presentation_file_id" => presentation_file.id,
      "position" => position,
      "poll_opts" => [
        %{"content" => gettext("Yes"), "vote_count" => 0},
        %{"content" => gettext("No"), "vote_count" => 0}
      ]
    })
  end

  defp build_changeset(_assigns, poll), do: Polls.change_poll(poll)

  defp build_poll_changeset(
         %{
           assigns: %{live_action: :new, presentation_file: presentation_file, position: position}
         },
         poll_params
       ) do
    %Polls.Poll{}
    |> Polls.change_poll(
      poll_params
      |> Map.put("enabled", false)
      |> Map.put("presentation_file_id", presentation_file.id)
      |> Map.put("position", position)
    )
  end

  defp build_poll_changeset(%{assigns: %{poll: poll}}, poll_params) do
    Polls.change_poll(poll, poll_params)
  end

  defp list_polls(assigns) do
    Polls.list_polls(assigns.presentation_file.id)
  end
end
