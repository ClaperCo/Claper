defmodule ClaperWeb.AttendeeSocket do
  use Phoenix.Socket

  channel "event:*", ClaperWeb.EventChannel

  @impl true
  def connect(_params, socket, %{session: session}) do
    attendee_identifier = session["attendee_identifier"]
    current_user = session["current_user"]
    {:ok, socket |> assign(attendee_identifier: attendee_identifier, current_user: current_user)}
  end

  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "attendee_socket:#{socket.assigns.attendee_identifier}"
end
