defmodule Lti13.DeploymentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Lti13.Deployments` context.
  """

  import Lti13.RegistrationsFixtures

  @doc """
  Generate a deployment.
  """
  def deployment_fixture(attrs \\ %{}) do
    registration = registration_fixture()

    {:ok, deployment} =
      attrs
      |> Enum.into(%{
        deployment_id: 1,
        registration_id: registration.id
      })
      |> Lti13.Deployments.create_deployment()

    deployment
  end
end
