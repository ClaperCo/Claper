defmodule Lti13.Users do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Lti13.Users.User

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_sub(sub) do
    Repo.get_by(User, sub: sub)
  end

  def get_or_create_user(%{sub: sub, email: email, issuer: issuer, client_id: client_id} = attrs) do
    case get_user_by_sub(sub) do
      nil ->
        case Claper.Accounts.get_user_by_email_or_create(email) do
          {:ok, claper_user} ->
            %{id: registration_id} =
              Lti13.Registrations.get_registration_by_issuer_client_id(issuer, client_id)

            updated_attrs =
              attrs
              |> Map.put(:user_id, claper_user.id)
              |> Map.put(:registration_id, registration_id)

            case create_user(updated_attrs) do
              {:ok, user} ->
                {:ok, user |> Repo.preload(:user)}

              {:error, _} ->
                {:error, %{reason: :invalid_user, msg: "Invalid user"}}
            end

          {:error, _} ->
            {:error, %{reason: :invalid_user, msg: "Invalid Claper user"}}
        end

      %User{} = user ->
        {:ok, user |> Repo.preload(:user)}
    end
  end
end
