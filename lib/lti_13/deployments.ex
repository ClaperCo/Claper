defmodule Lti13.Deployments do
  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Lti13.Deployments.Deployment

  @doc """
  Creates a deployment.

  ## Examples
      iex> create_deployment(%{deployment_id: 1, registration_id: 1})
      {:ok, %Deployment{}}
      iex> create_deployment(%{deployment_id: :bad_value, registration_id: 1})
      {:error, %Ecto.Changeset{}}
  """
  def create_deployment(attrs) do
    %Deployment{}
    |> Deployment.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a deployment by registration and deployment id.

  ## Examples
      iex> get_deployment(1, 1)
      %Deployment{}
      iex> get_deployment(1, :bad_value)
      nil
  """
  def get_deployment(registration_id, deployment_id) do
    Repo.one(
      from(r in Deployment,
        where: r.registration_id == ^registration_id and r.deployment_id == ^deployment_id
      )
    )
  end
end
