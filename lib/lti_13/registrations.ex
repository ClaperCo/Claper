defmodule Lti13.Registrations do
  import Ecto.Query, warn: false
  alias Lti13.Deployments.Deployment
  alias Claper.Repo
  alias Lti13.Registrations.Registration

  def create_registration(attrs) do
    %Registration{}
    |> Registration.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a registration and its first deployment atomically on behalf of `registrant`.

  Registrations created by administrators are approved immediately; all others stay
  pending until an administrator approves them.
  """
  def create_registration_with_deployment(
        registration_attrs,
        deployment_id,
        %Claper.Accounts.User{} = registrant
      ) do
    changeset =
      %Registration{}
      |> Registration.changeset(Map.put(registration_attrs, :user_id, registrant.id))
      |> maybe_auto_approve(registrant)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:registration, changeset)
    |> Ecto.Multi.insert(:deployment, fn %{registration: registration} ->
      Deployment.changeset(%Deployment{}, %{
        deployment_id: deployment_id,
        registration_id: registration.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{registration: registration, deployment: deployment}} ->
        {:ok, registration, deployment}

      {:error, _step, changeset, _changes} ->
        {:error, changeset}
    end
  end

  def get_registration_deployment(issuer, client_id, deployment_id) do
    case Repo.one(
           from(d in Deployment,
             join: r in Registration,
             on: d.registration_id == r.id,
             where:
               r.issuer == ^issuer and r.client_id == ^client_id and
                 d.deployment_id == ^deployment_id,
             select: {r, d}
           )
         ) do
      nil ->
        nil

      {r, d} ->
        {r, d}
    end
  end

  def get_registration_by_issuer_client_id(issuer, client_id) do
    Repo.one(
      from(registration in Registration,
        where: registration.issuer == ^issuer and registration.client_id == ^client_id,
        select: registration
      )
    )
  end

  @doc """
  Returns true when an administrator approved the platform registration.
  """
  def approved?(%Registration{approved_at: %NaiveDateTime{}}), do: true
  def approved?(_registration), do: false

  @doc """
  Lists all registrations, newest first, with registrant and approver preloaded.
  """
  def list_registrations do
    Repo.all(
      from(r in Registration,
        order_by: [desc: r.inserted_at, desc: r.id],
        preload: [:user, :approved_by]
      )
    )
  end

  def get_registration!(id), do: Repo.get!(Registration, id)

  @doc """
  Approves a registration. Only administrators may approve platforms.
  """
  def approve_registration(%Registration{} = registration, %Claper.Accounts.User{} = admin) do
    if admin?(admin) do
      registration
      |> Ecto.Changeset.change(approved_at: now(), approved_by_id: admin.id)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Revokes a registration's approval, blocking new logins and launches from it.
  """
  def revoke_registration(%Registration{} = registration, %Claper.Accounts.User{} = admin) do
    if admin?(admin) do
      registration
      |> Ecto.Changeset.change(approved_at: nil, approved_by_id: nil)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Error returned to platforms whose registration has not been approved.
  """
  def pending_error(%Registration{} = registration) do
    {:error,
     %{
       reason: :registration_pending,
       msg:
         "Registration with issuer \"#{registration.issuer}\" and client id \"#{registration.client_id}\" is pending administrator approval"
     }}
  end

  defp maybe_auto_approve(changeset, registrant) do
    if admin?(registrant) do
      Ecto.Changeset.change(changeset, approved_at: now(), approved_by_id: registrant.id)
    else
      changeset
    end
  end

  # Always re-read the role so a demoted administrator's stale session cannot approve.
  defp admin?(%Claper.Accounts.User{id: id}) do
    case Repo.get(Claper.Accounts.User, id) do
      nil -> false
      user -> Claper.Accounts.user_has_role?(user, "admin")
    end
  end

  defp now, do: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
end
