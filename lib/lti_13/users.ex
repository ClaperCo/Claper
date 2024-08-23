defmodule Lti13.Users do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Lti13.Users.User

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_sub_and_registration_id(sub, registration_id) do
    Repo.get_by(User, sub: sub, registration_id: registration_id)
  end

  def get_all_users_by_email(email) do
    Repo.all(from u in User, where: u.email == ^email)
  end

  def remove_user(claper_user, registration_id) do
    Repo.delete_all(
      from u in User,
        where: u.registration_id == ^registration_id and u.user_id == ^claper_user.id
    )
  end

  def get_or_create_user(
        %{
          sub: sub,
          email: email,
          registration_id: registration_id
        } = attrs
      ) do
    case get_user_by_sub_and_registration_id(sub, registration_id) do
      nil -> create_new_user(attrs, email, registration_id)
      %User{} = user -> {:ok, user |> Repo.preload(:user)}
    end
  end

  defp create_new_user(attrs, email, registration_id) do
    with {:ok, claper_user} <- Claper.Accounts.get_user_by_email_or_create(email),
         updated_attrs <-
           Map.merge(attrs, %{user_id: claper_user.id, registration_id: registration_id}),
         {:ok, user} <- create_user(updated_attrs) do
      {:ok, user |> Repo.preload(:user)}
    else
      _ -> {:error, %{reason: :invalid_user, msg: "Invalid user"}}
    end
  end
end
