defmodule ClaperWeb.AttendeeLiveAuth do
  import Phoenix.LiveView

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign(:attendee_identifier, session["attendee_identifier"])
      |> assign(:current_user, session["current_user"])

    {:cont, socket}
  end
end
