defmodule ClaperWeb.UserLiveAuth do
  import Phoenix.LiveView

  use Phoenix.VerifiedRoutes,
    endpoint: ClaperWeb.Endpoint,
    router: ClaperWeb.Router

  def on_mount(:default, _params, session, socket) do
    socket = ClaperWeb.UserAuth.mount_current_user(socket, session)

    cond do
      is_nil(socket.assigns.current_user) ->
        {:halt, redirect(socket, to: ~p"/users/log_in")}

      not Application.get_env(:claper, :email_confirmation) ->
        {:cont, socket}

      socket.assigns.current_user.confirmed_at ->
        {:cont, socket}

      true ->
        {:halt, redirect(socket, to: ~p"/users/register/confirm")}
    end
  end
end
