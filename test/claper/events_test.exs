defmodule Claper.EventsTest do
  use Claper.DataCase

  alias Claper.Events

  import Claper.{
    EventsFixtures,
    AccountsFixtures,
    PresentationsFixtures,
    PollsFixtures,
    FormsFixtures,
    EmbedsFixtures
  }

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

    test "import/3 transfer all interactions from an event to another" do
      user = user_fixture()
      from_event = event_fixture(%{user: user, name: "from event"})
      to_event = event_fixture(%{user: user, name: "to event"})
      from_presentation_file = presentation_file_fixture(%{event: from_event})
      from_poll = poll_fixture(%{presentation_file_id: from_presentation_file.id})
      to_presentation_file = presentation_file_fixture(%{event: to_event, hash: "444444"})

      assert {:ok, %Event{}} = Events.import(user.id, from_event.uuid, to_event.uuid)

      assert Enum.at(
               Claper.Presentations.get_presentation_file!(to_presentation_file.id, [:polls]).polls,
               0
             ).title == from_poll.title
    end

    test "import/3 fail with different user" do
      user = user_fixture()
      bad_user = user_fixture()
      from_event = event_fixture(%{user: bad_user, name: "from event"})
      to_event = event_fixture(%{user: user, name: "to event"})
      from_presentation_file = presentation_file_fixture(%{event: from_event})
      _from_poll = poll_fixture(%{presentation_file_id: from_presentation_file.id})
      _to_presentation_file = presentation_file_fixture(%{event: to_event, hash: "444444"})

      assert_raise Ecto.NoResultsError, fn ->
        Events.import(user.id, from_event.uuid, to_event.uuid)
      end
    end

    test "duplicate_event/2 duplicates an event" do
      user = user_fixture()
      original_event = event_fixture(%{user: user, name: "Original Event"})
      presentation_file = presentation_file_fixture(%{event: original_event})
      poll_fixture(%{presentation_file_id: presentation_file.id})
      form_fixture(%{presentation_file_id: presentation_file.id})
      embed_fixture(%{presentation_file_id: presentation_file.id})

      assert {:ok, duplicated_event} = Events.duplicate_event(user.id, original_event.uuid)

      assert duplicated_event.id != original_event.id
      assert duplicated_event.user_id == original_event.user_id
      assert duplicated_event.name == "Original Event (Copy)"
      assert duplicated_event.code != original_event.code
      assert duplicated_event.uuid != original_event.uuid

      # Check if the presentation file was duplicated
      duplicated_presentation_file =
        Claper.Presentations.get_presentation_file!(duplicated_event.id)

      assert duplicated_presentation_file.id != presentation_file.id
      assert duplicated_presentation_file.hash == presentation_file.hash
      assert duplicated_presentation_file.length == presentation_file.length

      # Check if polls, forms, and embeds were duplicated
      assert length(Claper.Polls.list_polls(duplicated_presentation_file.id)) == 1
      assert length(Claper.Forms.list_forms(duplicated_presentation_file.id)) == 1
      assert length(Claper.Embeds.list_embeds(duplicated_presentation_file.id)) == 1
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
