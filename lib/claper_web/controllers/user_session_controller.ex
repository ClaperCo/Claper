defmodule ClaperWeb.UserSessionController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias ClaperWeb.UserAuth

  def new(conn, _params) do
    oidc_auto_redirect_login = Application.get_env(:claper, :oidc)[:auto_redirect_login]

    conn
    |> redirect_to_login(oidc_auto_redirect_login)
  end

  defp redirect_to_login(conn, true) do
    conn |> redirect(to: "/users/oidc")
  end

  defp redirect_to_login(conn, false) do
    oidc_provider_name = Application.get_env(:claper, :oidc)[:provider_name]
    oidc_logo_url = Application.get_env(:claper, :oidc)[:logo_url]
    oidc_enabled = Application.get_env(:claper, :oidc)[:enabled]

    conn
    |> render("new.html",
      error_message: nil,
      oidc_provider_name: oidc_provider_name,
      oidc_logo_url: oidc_logo_url,
      oidc_enabled: oidc_enabled
    )
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
