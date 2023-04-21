defmodule ClaperWeb.UserLiveAuth do
  import Phoenix.LiveView
  import Phoenix.Component
  alias ClaperWeb.Router.Helpers, as: Routes

  def on_mount(:default, _params, %{"current_user" => current_user} = _session, socket) do
    socket =
      socket
      |> assign_new(:current_user, fn -> current_user end)

    {:cont, socket}

    # if current_user.confirmed_at do
    #   socket =
    #     socket
    #     |> assign_new(:current_user, fn -> current_user end)

    #   {:cont, socket}
    # else
    #   {:halt,
    #    redirect(socket,
    #      to: Routes.user_registration_path(socket, :confirm, %{email: current_user.email})
    #    )}
    # end
  end

  def on_mount(:default, _params, _session, socket),
    do: {:halt, redirect(socket, to: Routes.user_registration_path(socket, :confirm))}
end
