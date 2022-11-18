defmodule Claper.EventsTest do
  use Claper.DataCase

  alias Claper.Events
  import Claper.{EventsFixtures, AccountsFixtures}

  describe "events" do
    alias Claper.Events.Event

    @invalid_attrs %{name: nil, code: nil}

    test "list_events/1 returns all events of a user" do
      event = event_fixture()
      assert Events.list_events(event.user_id) == [event]
    end

    test "list_events/1 doesn't returns events of other users" do
      event = event_fixture()

      event2 = event_fixture()

      assert Events.list_events(event.user_id) == [event]
      assert Events.list_events(event.user_id) != [event2]
    end

    test "get_event!/2 returns the event with given id" do
      event = event_fixture()
      assert Events.get_event!(event.uuid) == event
    end

    test "get_user_event!/3 with invalid user raises exception" do
      event = event_fixture()
      event2 = event_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_user_event!(event.user_id, event2.uuid) == event
      end
    end

    test "create_event/1 with valid data creates a event" do
      user = user_fixture()

      valid_attrs = %{
        name: "some name",
        code: "code",
        user_id: user.id,
        started_at: NaiveDateTime.utc_now(),
        expired_at: NaiveDateTime.add(NaiveDateTime.utc_now(), 7200, :second)
      }

      assert {:ok, %Event{} = event} = Events.create_event(valid_attrs)
      assert event.name == "some name"
    end

    test "create_event/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Events.create_event(@invalid_attrs)
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.name == "some updated name"
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, @invalid_attrs)
      assert event == Events.get_event!(event.uuid)
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()

      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.uuid) end
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end
  end
end
