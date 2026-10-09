defmodule ClaperWeb.UserSessionController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias Claper.Accounts.Oidc
  alias ClaperWeb.UserAuth

  def new(conn, _params) do
    oidc_auto_redirect_login = Application.get_env(:claper, :oidc)[:auto_redirect_login]

    conn
    |> redirect_to_login(oidc_auto_redirect_login)
  end

  # Auto redirect on: go straight to the first configured provider, from the
  # database when one is stored there, from the environment otherwise.
  defp redirect_to_login(conn, true) do
    case Oidc.list_active_providers() do
      [provider | _rest] -> redirect(conn, to: "/users/auth/#{provider.slug}")
      [] -> redirect_to_legacy_provider_or_render(conn)
    end
  end

  defp redirect_to_login(conn, false), do: render_login(conn, nil)

  defp redirect_to_legacy_provider_or_render(conn) do
    if Application.get_env(:claper, :oidc)[:enabled] do
      redirect(conn, to: "/users/oidc")
    else
      render_login(conn, nil)
    end
  end

  defp render_login(conn, error_message) do
    oidc = Application.get_env(:claper, :oidc)

    render(conn, "new.html",
      error_message: error_message,
      oidc_providers: Oidc.list_active_providers(),
      oidc_provider_name: oidc[:provider_name],
      oidc_logo_url: oidc[:logo_url],
      oidc_enabled: oidc[:enabled],
      password_login_disabled: Oidc.password_login_disabled?()
    )
  end

  # def create(conn, %{"user" => %{"email" => email}} = _user_params) do
  #  Accounts.deliver_magic_link(email, &url(~p"/users/magic/#{&1}"))

  #  conn
  #  |> redirect(to: ~p"/users/register/confirm?#{[%{email: email}]}")
  # end
  def create(conn, %{"user" => user_params}) do
    if Oidc.password_login_disabled?() do
      redirect_to_login(conn, true)
    else
      do_create(conn, user_params)
    end
  end

  defp do_create(conn, user_params) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      if Application.get_env(:claper, :email_confirmation) and !user.confirmed_at do
        render_login(
          conn,
          "You need to confirm your account before logging in. Please check your email for confirmation instructions."
        )
      else
        UserAuth.log_in_user(conn, user, user_params)
      end
    else
      render_login(conn, "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
