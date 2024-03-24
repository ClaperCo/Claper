defmodule ClaperWeb.UserSessionController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias ClaperWeb.UserAuth

  def new(conn, _params) do
    conn
    |> render("new.html", error_message: nil)
  end

  # def create(conn, %{"user" => %{"email" => email}} = _user_params) do
  #  Accounts.deliver_magic_link(email, &url(~p"/users/magic/#{&1}"))

  #  conn
  #  |> redirect(to: ~p"/users/register/confirm?#{[%{email: email}]}")
  # end
  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
