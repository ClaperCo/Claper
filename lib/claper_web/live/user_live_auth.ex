defmodule ClaperWeb.UserLiveAuth do
  import Phoenix.LiveView
  import Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: ClaperWeb.Endpoint,
    router: ClaperWeb.Router

  def on_mount(:default, _params, %{"current_user" => current_user} = _session, socket) do
    socket = assign_new(socket, :current_user, fn -> current_user end)

    cond do
      not Application.get_env(:claper, :email_confirmation) ->
        {:cont, socket}

      current_user.confirmed_at ->
        {:cont, socket}

      true ->
        {:halt, redirect(socket, to: ~p"/users/register/confirm")}
    end
  end

  def on_mount(:default, _params, _session, socket),
    do: {:halt, redirect(socket, to: ~p"/users/register/confirm")}
end
