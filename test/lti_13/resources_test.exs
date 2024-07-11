defmodule Lti13.ResourcesTest do
  alias Lti13.Resources
  use Claper.DataCase

  alias Lti13.Resources
  alias Lti13.Resources.Resource

  import Lti13.RegistrationsFixtures
  import Claper.EventsFixtures

  describe "resources" do
    setup do
      %{registration: registration_fixture(), event: event_fixture()}
    end

    test "create_resource/1 with valid attributes", %{registration: registration, event: event} do
      attrs = %{
        title: "Resource 1",
        resource_id: 1,
        registration_id: registration.id,
        event_id: event.id
      }

      assert {:ok, %Resource{}} = Resources.create_resource(attrs)
    end

    test "create_resource/1 with invalid attributes" do
      attrs = %{
        title: "Resource 1",
        resource_id: "test"
      }

      assert {:error, %Ecto.Changeset{}} = Resources.create_resource(attrs)
    end

    test "get_resource_by_id_and_registration/1 with valid attributes", %{
      registration: registration,
      event: event
    } do
      attrs = %{
        title: "Resource 1",
        resource_id: 1,
        registration_id: registration.id,
        event_id: event.id
      }

      assert {:ok, %Resource{} = resource} = Resources.create_resource(attrs)

      assert %Resource{id: id} = Resources.get_resource_by_id_and_registration(1, registration.id)
      assert resource.id == id
    end

    test "get_resource_by_id_and_registration/1 with invalid attributes", %{
      registration: registration,
      event: event
    } do
      attrs = %{
        title: "Resource 1",
        resource_id: 1,
        registration_id: registration.id,
        event_id: event.id
      }

      assert {:ok, %Resource{}} = Resources.create_resource(attrs)

      assert is_nil(Resources.get_resource_by_id_and_registration(32, 32))
    end

    test "create_resource_with_event/1 with valid attributes and lti_user", %{
      registration: registration
    } do
      lti_user = %Lti13.Users.User{
        user_id: 1,
        registration_id: registration.id
      }

      attrs = %{
        title: "Resource 1",
        resource_id: 1,
        lti_user: lti_user
      }

      assert {:ok, %Resource{event: %Claper.Events.Event{} = event} = resource} =
               Resources.create_resource_with_event(attrs)

      assert resource.title == "Resource 1"
      assert resource.resource_id == 1
      assert resource.registration_id == registration.id
      assert resource.event_id == event.id
    end

    test "create_resource_with_event/1 with invalid attributes", %{registration: registration} do
      lti_user = %Lti13.Users.User{
        user_id: 1,
        registration_id: registration.id
      }

      attrs = %{
        title: nil,
        resource_id: nil,
        lti_user: lti_user
      }

      assert {:error, %{reason: :invalid_resource, msg: "Failed to create resource"}} =
               Resources.create_resource_with_event(attrs)
    end
  end
end
