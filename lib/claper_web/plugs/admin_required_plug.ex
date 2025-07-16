defmodule ClaperWeb.Plugs.AdminRequiredPlug do
  @moduledoc """
  Plug to ensure that the current user has admin role.
  
  This plug should be used after the authentication plug to ensure
  that only admin users can access certain routes.
  """
  
  import Plug.Conn
  import Phoenix.Controller
  alias ClaperWeb.Router.Helpers, as: Routes
  alias Claper.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    if user && Accounts.user_has_role?(user, "admin") do
      conn
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt()
    end
  end
end
