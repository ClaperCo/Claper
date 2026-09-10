defmodule ClaperWeb.PollLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Polls
  alias Phoenix.HTML.Form

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

  # `input_value/2` hands back whatever the form currently holds: the atom stored
  # on the poll while nothing has changed, but the raw string from the params
  # after any phx-change -- and a change event that re-submits the type a saved
  # poll already has produces no changeset change to fall back on. Compare the
  # two on one shape, or an edited word cloud starts rendering as a choice poll.
  defp word_cloud?(form) do
    to_string(Form.input_value(form, :type)) == "word_cloud"
  end

  # A choice poll needs its options, and that requirement sits on the association
  # itself, which has no input of its own to hang the message on while the list
  # is empty -- the state a word cloud turned back into a choice poll starts in.
  # Without this the save just appears to do nothing.
  #
  # Only once the changeset has an action, the same rule `error_tag/2` follows
  # for every other field: an untouched changeset carries the errors of a poll as
  # it stands, and a saved choice poll whose last option was removed elsewhere
  # would otherwise open the form already showing the message in red.
  defp poll_opts_missing?(%{source: %Ecto.Changeset{action: action, errors: errors}})
       when not is_nil(action),
       do: Keyword.has_key?(errors, :poll_opts)

  defp poll_opts_missing?(_form), do: false
end
