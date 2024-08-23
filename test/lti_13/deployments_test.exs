defmodule Lti13.DeploymentsTest do
  alias Lti13.Registrations
  use Claper.DataCase

  alias Lti13.Deployments
  alias Lti13.Deployments.Deployment

  import Lti13.{RegistrationsFixtures, DeploymentsFixtures}

  describe "deployments" do
    setup do
      %{registration: registration_fixture()}
    end

    test "create_deployment/1 with valid attributes", %{registration: registration} do
      assert {:ok, %Deployment{}} =
               Deployments.create_deployment(%{deployment_id: 1, registration_id: registration.id})
    end

    test "get_deployment/2 with existing deployment", %{registration: registration} do
      deployment = deployment_fixture(deployment_id: 1, registration_id: registration.id)
      assert %Deployment{} = Deployments.get_deployment(registration.id, deployment.deployment_id)
    end

    test "get_deployment/2 with non-existent deployment", %{registration: registration} do
      deployment_fixture(deployment_id: 1, registration_id: registration.id)
      assert is_nil(Deployments.get_deployment(registration.id, -1))
    end

    test "create and get deployment and registration by deployment_id" do
      registration = registration_fixture()

      deployment_id = 13
      issuer = registration.issuer
      client_id = registration.client_id
      registration_id = registration.id

      deployment = %{
        deployment_id: deployment_id,
        registration_id: registration_id
      }

      assert {:ok,
              %Deployment{
                deployment_id: ^deployment_id,
                registration_id: ^registration_id
              }} = Deployments.create_deployment(deployment)

      assert %Deployment{
               deployment_id: ^deployment_id,
               registration_id: ^registration_id
             } = Deployments.get_deployment(registration_id, deployment_id)

      assert {^registration,
              %Deployment{
                deployment_id: ^deployment_id,
                registration_id: ^registration_id
              }} = Registrations.get_registration_deployment(issuer, client_id, deployment_id)
    end
  end
end
