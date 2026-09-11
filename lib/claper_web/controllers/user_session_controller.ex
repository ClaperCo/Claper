defmodule ClaperWeb.UserSessionController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias ClaperWeb.UserAuth

  def new(conn, params) do
    oidc_auto_redirect_login = Application.get_env(:claper, :oidc)[:auto_redirect_login]

    conn
    |> maybe_store_return_to(params)
    |> redirect_to_login(oidc_auto_redirect_login)
  end

  # A page that sends a visitor here can name where to send them back to, the
  # same session key `UserAuth.log_in_user/3` already reads for LTI launches.
  defp maybe_store_return_to(conn, %{"return_to" => return_to}) when is_binary(return_to) do
    if local_path?(return_to) do
      put_session(conn, :user_return_to, return_to)
    else
      conn
    end
  end

  defp maybe_store_return_to(conn, _params), do: conn

  # The characters `Phoenix.Controller.redirect/2` refuses in a local path. A
  # path holding one of them reaches `redirect(to: ...)` and raises there, so it
  # must not make it into the session in the first place.
  @unsafe_local_path_chars ["\\", "/%09", "/\t"]

  # Only same origin paths, so a crafted link cannot turn the login form into
  # an open redirect or crash the login it is attached to.
  defp local_path?(path) do
    String.starts_with?(path, "/") and not String.starts_with?(path, "//") and
      not String.contains?(path, @unsafe_local_path_chars)
  end

  defp redirect_to_login(conn, true) do
    conn |> redirect(to: "/users/oidc")
  end

  defp redirect_to_login(conn, false) do
    oidc_provider_name = Application.get_env(:claper, :oidc)[:provider_name]
    oidc_logo_url = Application.get_env(:claper, :oidc)[:logo_url]
    oidc_enabled = Application.get_env(:claper, :oidc)[:enabled]
    password_login_disabled = Application.get_env(:claper, :oidc)[:disable_password_login]

    conn
    |> render("new.html",
      error_message: nil,
      oidc_provider_name: oidc_provider_name,
      oidc_logo_url: oidc_logo_url,
      oidc_enabled: oidc_enabled,
      password_login_disabled: password_login_disabled
    )
  end

  # def create(conn, %{"user" => %{"email" => email}} = _user_params) do
  #  Accounts.deliver_magic_link(email, &url(~p"/users/magic/#{&1}"))

  #  conn
  #  |> redirect(to: ~p"/users/register/confirm?#{[%{email: email}]}")
  # end
  def create(conn, %{"user" => user_params}) do
    if Application.get_env(:claper, :oidc)[:disable_password_login] do
      conn |> redirect(to: "/users/oidc")
    else
      do_create(conn, user_params)
    end
  end

  defp do_create(conn, user_params) do
    %{"email" => email, "password" => password} = user_params

    oidc_provider_name = Application.get_env(:claper, :oidc)[:provider_name]
    oidc_logo_url = Application.get_env(:claper, :oidc)[:logo_url]
    oidc_enabled = Application.get_env(:claper, :oidc)[:enabled]
    password_login_disabled = Application.get_env(:claper, :oidc)[:disable_password_login]

    if user = Accounts.get_user_by_email_and_password(email, password) do
      if Application.get_env(:claper, :email_confirmation) and !user.confirmed_at do
        render(conn, "new.html",
          error_message:
            "You need to confirm your account before logging in. Please check your email for confirmation instructions.",
          oidc_provider_name: oidc_provider_name,
          oidc_logo_url: oidc_logo_url,
          oidc_enabled: oidc_enabled,
          password_login_disabled: password_login_disabled
        )
      else
        UserAuth.log_in_user(conn, user, user_params)
      end
    else
      render(conn, "new.html",
        error_message: "Invalid email or password",
        oidc_provider_name: oidc_provider_name,
        oidc_logo_url: oidc_logo_url,
        oidc_enabled: oidc_enabled,
        password_login_disabled: password_login_disabled
      )
    end
  end

  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
  end
end
