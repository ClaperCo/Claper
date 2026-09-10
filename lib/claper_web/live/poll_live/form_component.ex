defmodule ClaperWeb.PollLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Polls

  @impl true
  def update(%{poll: poll} = assigns, socket) do
    changeset = Polls.change_poll(poll)

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
      socket.assigns.poll
      |> for_selected_type(poll_params)
      |> Polls.change_poll(poll_params)
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

    poll_opt = Enum.at(Ecto.Changeset.get_field(changeset, :poll_opts), opt)

    {:noreply, assign(socket, :changeset, changeset |> Polls.remove_poll_opt(poll_opt))}
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

  defp list_polls(assigns) do
    Polls.list_polls(assigns.presentation_file.id)
  end

  # `input_value/2` answers with the atom from the changeset on the first render
  # and with the raw param string on every following phx-change, so the type is
  # compared on its string form -- otherwise editing a saved slider poll flips
  # the form to the choice branch on the first keystroke.
  defp slider_selected?(form), do: to_string(input_value(form, :type)) == "slider"

  # The options on screen belong to the type that is selected: while the
  # presenter switches a saved poll over, the rows kept for the other type (the
  # author's choices, or the attendees' rating buckets) must not be offered as
  # the new type's options.
  defp for_selected_type(%Polls.Poll{} = poll, %{"type" => selected}) do
    cond do
      to_string(poll.type) == selected -> poll
      selected == "slider" -> %{poll | poll_opts: []}
      true -> %{poll | poll_opts: [%Polls.PollOpt{}, %Polls.PollOpt{}]}
    end
  end

  defp for_selected_type(poll, _poll_params), do: poll
end
