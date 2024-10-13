defmodule ClaperWeb.EventChannel do
  use Phoenix.Channel
  alias ClaperWeb.Presence

  def join("event:" <> event_uuid, _params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :event_uuid, event_uuid)}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} = Presence.track(socket, socket.assigns.attendee_identifier, %{
      online_at: inspect(System.system_time(:second))
    })
    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_info({:post_created, post}, socket) do
    broadcast!(socket, "post_created", post)
    {:noreply, socket}
  end
end
