defmodule ClaperWeb.UserSessionController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias ClaperWeb.UserAuth

  def new(conn, _params) do
    conn
    |> render("new.html", error_message: nil)
  end

  def create(conn, %{"user" => %{"email" => email}} = _user_params) do
    Accounts.deliver_magic_link(email, &Routes.user_confirmation_url(conn, :confirm_magic, &1))

    conn
    |> redirect(to: Routes.user_registration_path(conn, :confirm, %{email: email}))
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
