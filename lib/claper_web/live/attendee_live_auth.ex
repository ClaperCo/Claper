defmodule ClaperWeb.AttendeeLiveAuth do
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    socket =
      socket
      |> assign(:attendee_identifier, session["attendee_identifier"])
      |> ClaperWeb.UserAuth.mount_current_user(session)

    {:cont, socket}
  end
end
