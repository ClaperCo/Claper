defmodule ClaperWeb.UserResetPasswordController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias Claper.Accounts.User

  plug(:get_user_by_reset_password_token when action in [:edit])

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &Routes.user_reset_password_url(conn, :edit, &1)
      )
    end

    # Regardless of the outcome, show an impartial success/error message.
    conn
    |> put_flash(
      :info,
      gettext(
        "If your email is in our system, you'll receive instructions to reset your password shortly."
      )
    )
    |> redirect(to: "/")
  end

  def edit(conn, %{"token" => token}) do
    changeset = Accounts.change_user_password(%User{})
    render(conn, "edit.html", changeset: changeset, token: token)
  end

  def update(conn, %{"user" => user_params, "token" => token}) do
    user = Accounts.get_user!(get_session(conn, "user_id"))

    case Accounts.reset_user_password(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, gettext("Password updated successfully."))
        |> redirect(to: "/")

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset, token: token)
    end
  end

  defp get_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if user = Accounts.get_user_by_reset_password_token(token) do
      put_session(conn, "user_id", user.id)
    else
      conn
      |> put_flash(:error, gettext("Reset password link is invalid or it has expired."))
      |> redirect(to: "/")
      |> halt()
    end
  end
end
