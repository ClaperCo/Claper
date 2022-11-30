defmodule ClaperWeb.UserRegistrationController do
  use ClaperWeb, :controller

  alias Claper.Accounts
  alias Claper.Accounts.User
  alias ClaperWeb.UserAuth

  def new(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def confirm(conn, _params) do
    render(conn, "confirm.html")
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        #{:ok, _} =
        #  Accounts.deliver_user_confirmation_instructions(
        #    user,
        #    &Routes.user_confirmation_url(conn, :update, &1)
        #  )

        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
