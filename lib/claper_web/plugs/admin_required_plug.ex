defmodule ClaperWeb.Plugs.AdminRequiredPlug do
  @moduledoc """
  Plug to ensure that the current user has admin role.

  This plug should be used after the authentication plug to ensure
  that only admin users can access certain routes.
  """

  import Plug.Conn
  import Phoenix.Controller

  use Phoenix.VerifiedRoutes,
    endpoint: ClaperWeb.Endpoint,
    router: ClaperWeb.Router,
    statics: ClaperWeb.static_paths()

  alias Claper.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && Accounts.user_has_role?(user, "admin") do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/events")
      |> halt()
    end
  end
end
