defmodule Claper.EventsTest do
  use Claper.DataCase

  alias Claper.Events
  alias Claper.Events.{Event, ActivityLeader}

  import Claper.{
    EventsFixtures,
    AccountsFixtures,
    PresentationsFixtures,
    PollsFixtures,
    FormsFixtures,
    EmbedsFixtures
  }

  setup_all do
    sandbox_owner_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Claper.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(sandbox_owner_pid) end)

    alice = user_fixture(%{email: "alice@example.com"})
    bob = user_fixture(%{email: "bob@example.com"})
    carol = user_fixture(%{email: "carol@example.com"})

    now = NaiveDateTime.utc_now()

    alice_active_events =
      for _ <- 1..12 do
        event_fixture(%{user: alice})
      end

    alice_expired_events = []

    bob_active_events = []

    bob_expired_events =
      for i <- 1..12 do
        event_fixture(%{user: bob, expired_at: NaiveDateTime.add(now, i - 1, :hour)})
      end

    carol_active_events =
      for _ <- 1..6 do
        event =
          event_fixture(%{user: carol})

        activity_leader_fixture(%{event: event, user: alice})
        event
      end

    carol_expired_events =
      for i <- 1..6 do
        event =
          event_fixture(%{user: carol, expired_at: NaiveDateTime.add(now, i - 1, :hour)})

        activity_leader_fixture(%{event: event, user: bob})
        event
      end

    [
      sandbox_owner_pid: sandbox_owner_pid,
      alice: alice,
      alice_active_events: alice_active_events,
      alice_expired_events: alice_expired_events,
      alice_events: alice_active_events ++ alice_expired_events,
      bob: bob,
      bob_active_events: bob_active_events,
      bob_expired_events: bob_expired_events,
      bob_events: bob_active_events ++ bob_expired_events,
      carol: carol,
      carol_active_events: carol_active_events,
      carol_expired_events: carol_expired_events,
      carol_events: carol_active_events ++ carol_expired_events
    ]
  end

  describe "listing events" do
    test "list_events/2 lists all events of a user but not others", context do
      assert Events.list_events(context.alice.id) == list(context.alice_events)
      assert Events.list_events(context.bob.id) == list(context.bob_events)
      assert Events.list_events(context.carol.id) == list(context.carol_events)
    end

    test "paginate_events/3 paginates all events of a user but not others", context do
      assert Events.paginate_events(context.alice.id) ==
               paginate(context.alice_events)

      params = %{"page" => 2}

      assert Events.paginate_events(context.alice.id, params) ==
               paginate(context.alice_events, params)

      assert Events.paginate_events(context.bob.id) ==
               paginate(context.bob_events)

      params = %{"page" => 2, "page_size" => 12}

      assert Events.paginate_events(context.bob.id, params) ==
               paginate(context.bob_events, params)
    end

    test "list_not_expired_events/2 lists all active events for a user but not others",
         context do
      assert Events.list_not_expired_events(context.alice.id) ==
               list(context.alice_active_events)

      assert Events.list_not_expired_events(context.bob.id) ==
               list(context.bob_active_events)

      assert Events.list_not_expired_events(context.carol.id) ==
               list(context.carol_active_events)
    end

    test "paginate_not_expired_events/3 paginates all active events for a user but not others",
         context do
      assert Events.paginate_not_expired_events(context.alice.id) ==
               paginate(context.alice_active_events)

      assert Events.paginate_not_expired_events(context.bob.id) ==
               paginate(context.bob_active_events)

      params = %{"page" => 2, "page_size" => 10}

      assert Events.paginate_not_expired_events(context.carol.id, params) ==
               paginate(context.carol_active_events, params)
    end

    test "list_expired_events/2 lists all expired events for a user but not others", context do
      assert Events.list_expired_events(context.alice.id) ==
               Enum.reverse(context.alice_expired_events)

      assert Events.list_expired_events(context.bob.id) ==
               Enum.reverse(context.bob_expired_events)

      assert Events.list_expired_events(context.carol.id) ==
               Enum.reverse(context.carol_expired_events)
    end

    test "paginate_expired_events/3 lists all expired events for a user but not others",
         context do
      assert Events.paginate_expired_events(context.alice.id) ==
               paginate(context.alice_expired_events)

      assert Events.paginate_expired_events(context.bob.id) ==
               paginate(context.bob_expired_events)

      params = %{"page" => 2, "page_size" => 10}

      assert Events.paginate_expired_events(context.bob.id, params) ==
               paginate(context.bob_expired_events, params)

      assert Events.paginate_expired_events(context.carol.id) ==
               paginate(context.carol_expired_events)
    end

    test "list_managed_events_by/2 lists all managed events by user but not others", context do
      assert Events.list_managed_events_by(context.alice.email) ==
               list(context.carol_active_events)

      assert Events.list_managed_events_by(context.bob.email) ==
               list(context.carol_expired_events)

      assert Events.list_managed_events_by(context.carol.email) == []
    end

    test "paginate_managed_events_by/3 paginates all managed events by user but not others",
         context do
      assert Events.paginate_managed_events_by(context.alice.email) ==
               paginate(context.carol_active_events)

      assert Events.paginate_managed_events_by(context.bob.email) ==
               paginate(context.carol_expired_events)

      assert Events.paginate_managed_events_by(context.carol.email) == {[], 0, 0}
    end
  end

  describe "counting events" do
    test "count_managed_events_by/1 counts all managed events by user", context do
      assert Events.count_managed_events_by(context.alice.email) ==
               Enum.count(context.carol_active_events)

      assert Events.count_managed_events_by(context.bob.email) ==
               Enum.count(context.carol_expired_events)

      assert Events.count_managed_events_by(context.carol.email) == 0
    end

    test "count_expired_events/1 counts all expired events for user", context do
      assert Events.count_expired_events(context.alice.id) ==
               Enum.count(context.alice_expired_events)

      assert Events.count_expired_events(context.bob.id) == Enum.count(context.bob_expired_events)

      assert Events.count_expired_events(context.carol.id) ==
               Enum.count(context.carol_expired_events)
    end

    test "count_events_month/1 counts all events for user created in the last 30 days",
         context do
      assert Events.count_events_month(context.alice.id) ==
               Enum.count(context.alice_active_events) + Enum.count(context.alice_expired_events)

      assert Events.count_events_month(context.bob.id) ==
               Enum.count(context.bob_active_events) + Enum.count(context.bob_expired_events)

      assert Events.count_events_month(context.carol.id) ==
               Enum.count(context.carol_active_events) + Enum.count(context.carol_expired_events)
    end
  end

  describe "getting events" do
    test "get_event!/2 gets event by serial ID and UUID" do
      event = event_fixture()
      assert Events.get_event!(event.id) == event
      assert Events.get_event!(to_string(event.id)) == event
      assert Events.get_event!(event.uuid) == event
    end

    test "get_managed_event!/3 gets event managed by owner and leader, raises if neither",
         context do
      event = Enum.at(context.carol_active_events, 0)
      assert Events.get_managed_event!(context.alice, event.uuid) == event
      assert Events.get_managed_event!(context.carol, event.uuid) == event

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_managed_event!(context.bob, event.uuid)
      end
    end

    test "get_managed_event!/3 works for the owner of an event with no leaders",
         context do
      event = Enum.at(context.alice_active_events, 0)
      assert Events.get_managed_event!(context.alice, event.uuid) == event
    end

    test "get_user_event!/3 gets event by owner, raises if not", context do
      event = Enum.at(context.alice_active_events, 0)
      assert Events.get_user_event!(context.alice.id, event.uuid) == event

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_user_event!(context.bob.id, event.uuid)
      end
    end

    test "get_event_with_code!/2 gets non-expired event by code, raises if not found", context do
      active_event = Enum.at(context.carol_active_events, 0)
      expired_event = Enum.at(context.carol_expired_events, 0)

      assert Events.get_event_with_code!(active_event.code) == active_event

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_event_with_code!(expired_event.code)
      end

      assert_raise Ecto.NoResultsError, fn ->
        Events.get_event_with_code!("ABC123")
      end
    end

    test "get_event_with_code/2 gets non-expired event by code, returns nil if not found",
         context do
      active_event = Enum.at(context.carol_active_events, 0)
      expired_event = Enum.at(context.carol_expired_events, 0)

      assert Events.get_event_with_code(active_event.code) == active_event
      assert Events.get_event_with_code(expired_event.code) == nil
      assert Events.get_event_with_code("ABC123") == nil
    end
  end

  describe "writing events" do
    test "create_event/1 with valid data creates a event" do
      user = user_fixture()

      attrs = %{
        name: "some name",
        code: "12345",
        user_id: user.id,
        started_at:
          NaiveDateTime.utc_now(:second)
          |> NaiveDateTime.truncate(:second),
        expired_at:
          NaiveDateTime.add(NaiveDateTime.utc_now(), 2, :hour)
          |> NaiveDateTime.truncate(:second)
      }

      assert {:ok, %Event{} = event} = Events.create_event(attrs)

      assert event.name == attrs.name
      assert event.code == attrs.code
      assert event.user_id == attrs.user_id
      assert event.started_at == attrs.started_at
      assert attrs.expired_at == event.expired_at
    end

    test "create_event/1 with invalid data returns error changeset" do
      user = user_fixture()

      attrs = %{
        name: "some name",
        code: "12345",
        user_id: user.id,
        started_at:
          NaiveDateTime.utc_now(:second)
          |> NaiveDateTime.truncate(:second),
        expired_at:
          NaiveDateTime.add(NaiveDateTime.utc_now(), 2, :hour)
          |> NaiveDateTime.truncate(:second)
      }

      too_short_code = "tiny"

      assert {:error, %Ecto.Changeset{}} = Events.create_event(Map.delete(attrs, :name))
      assert {:error, %Ecto.Changeset{}} = Events.create_event(Map.delete(attrs, :code))
      assert {:error, %Ecto.Changeset{}} = Events.create_event(Map.delete(attrs, :user_id))
      assert {:error, %Ecto.Changeset{}} = Events.create_event(Map.delete(attrs, :started_at))

      assert {:error, %Ecto.Changeset{}} =
               Events.create_event(Map.merge(attrs, %{code: too_short_code}))
    end

    test "duplicate_event/2 duplicates an event without presentation association" do
      original = event_fixture()
      {:ok, duplicate} = Events.duplicate_event(original.user_id, original.uuid)

      assert duplicate.name == "#{original.name} (Copy)"
      assert duplicate.id != original.id
      assert duplicate.code != original.code
    end

    test "duplicate_event/2 duplicates an event with presentation associations" do
      original = event_fixture()
      presentation_file = presentation_file_fixture(%{event: original})
      presentation_state = presentation_state_fixture(%{presentation_file: presentation_file})

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          poll_opts: [
            %{content: "some option 1", vote_count: 1},
            %{content: "some option 2", vote_count: 2}
          ]
        })

      poll_fixture(%{presentation_file_id: presentation_file.id})

      form = form_fixture(%{presentation_file_id: presentation_file.id})
      form_fixture(%{presentation_file_id: presentation_file.id})
      embed = embed_fixture(%{presentation_file_id: presentation_file.id})
      embed_fixture(%{presentation_file_id: presentation_file.id})

      duplicate =
        Events.duplicate_event(original.user_id, original.uuid)
        |> then(fn {:ok, duplicate} ->
          duplicate
          |> Repo.preload(
            presentation_file: [:embeds, :forms, :presentation_state, polls: [:poll_opts]]
          )
        end)

      # Event
      assert duplicate.id != original.id
      assert duplicate.uuid != original.uuid
      assert duplicate.code != original.code
      assert duplicate.name == "#{original.name} (Copy)"
      assert duplicate.user_id == original.user_id

      # Presentation file
      assert duplicate.presentation_file.id != presentation_file.id
      assert duplicate.presentation_file.hash == presentation_file.hash
      assert duplicate.presentation_file.length == presentation_file.length
      assert duplicate.presentation_file.event_id != presentation_file.event_id
      assert duplicate.presentation_file.event_id == duplicate.id

      # Presentation state
      duplicate_state = duplicate.presentation_file.presentation_state
      assert duplicate_state.id != presentation_state.id
      assert duplicate_state.presentation_file_id != presentation_state.presentation_file_id
      assert duplicate_state.presentation_file_id == duplicate.presentation_file.id

      # Polls
      [duplicate_poll, _] = duplicate.presentation_file.polls
      assert duplicate_poll.id != poll.id
      assert duplicate_poll.presentation_file_id != poll.presentation_file_id
      assert duplicate_poll.presentation_file_id == duplicate.presentation_file.id
      assert duplicate_poll.title == poll.title
      assert duplicate_poll.position == poll.position

      # Poll options
      [o1, o2] = poll.poll_opts
      [do1, do2] = duplicate_poll.poll_opts

      assert do1.id != o1.id
      assert do1.poll_id != o1.poll_id
      assert do1.poll_id == duplicate_poll.id
      assert do1.content == o1.content
      assert do1.vote_count == 0

      assert do2.id != o2.id
      assert do2.poll_id != o2.poll_id
      assert do2.poll_id == duplicate_poll.id
      assert do2.content == o2.content
      assert do2.vote_count == 0

      # Forms
      [duplicate_form, _] = duplicate.presentation_file.forms
      assert duplicate_form.id != form.id
      assert duplicate_form.presentation_file_id != form.presentation_file_id
      assert duplicate_form.presentation_file_id == duplicate.presentation_file.id
      assert duplicate_form.enabled == form.enabled
      assert duplicate_form.fields == form.fields
      assert duplicate_form.position == form.position
      assert duplicate_form.title == form.title

      # Embeds
      [duplicate_embed, _] = duplicate.presentation_file.embeds
      assert duplicate_embed.id != embed.id
      assert duplicate_embed.presentation_file_id != embed.presentation_file_id
      assert duplicate_embed.presentation_file_id == duplicate.presentation_file.id
      assert(duplicate_embed.attendee_visibility == embed.attendee_visibility)
      assert duplicate_embed.content == embed.content
      assert duplicate_embed.enabled == embed.enabled
      assert duplicate_embed.position == embed.position
      assert duplicate_embed.provider == embed.provider
      assert duplicate_embed.title == embed.title
    end

    test "duplicate_event/2 raises when an invalid user-event is supplied", context do
      original = Enum.at(context.alice_active_events, 0)

      assert_raise Ecto.NoResultsError, fn ->
        Events.duplicate_event(context.bob.id, original.uuid)
      end
    end

    test "update_event/2 with valid data updates the event" do
      event = event_fixture()
      update_attrs = %{name: "some updated name"}

      assert {:ok, %Event{} = event} = Events.update_event(event, update_attrs)
      assert event.name == "some updated name"
    end

    test "update_event/2 with invalid data returns error changeset" do
      event = event_fixture()

      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{name: nil})
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{code: nil})
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{code: "tiny"})
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{user_id: nil})
      assert {:error, %Ecto.Changeset{}} = Events.update_event(event, %{started_at: nil})

      assert event == Events.get_event!(event.uuid)
    end

    test "change_event/1 returns a event changeset" do
      event = event_fixture()
      assert %Ecto.Changeset{} = Events.change_event(event)
    end

    test "terminate_event/1 terminates an event and broadcasts it" do
      event = event_fixture()
      assert event.expired_at == nil

      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event.uuid}")
      {:ok, event} = Events.terminate_event(event)

      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), event.expired_at) |> abs() < 1
      assert_received {:event_terminated, uuid}
      assert uuid == event.uuid
    end

    test "delete_event/1 deletes the event" do
      event = event_fixture()

      assert {:ok, %Event{}} = Events.delete_event(event)
      assert_raise Ecto.NoResultsError, fn -> Events.get_event!(event.uuid) end
    end
  end

  describe "leading events" do
    test "led_by?/2", context do
      assert Events.led_by?(context.alice.email, Enum.at(context.carol_active_events, 0)) == true
      assert Events.led_by?(context.bob.email, Enum.at(context.carol_active_events, 0)) == false
    end

    test "create_activity_leader/1 with valid data creates an activity leader" do
      attrs = %{
        email: "dan@example.com"
      }

      {:ok, leader = %ActivityLeader{}} = Events.create_activity_leader(attrs)
      assert leader.email == attrs.email

      event = event_fixture()

      attrs = %{
        email: "dan@example.com",
        event_id: event.id
      }

      {:ok, leader = %ActivityLeader{}} = Events.create_activity_leader(attrs)
      assert leader.email == attrs.email
      assert leader.event_id == attrs.event_id
    end

    test "create_activity_leader/1 with invalid data returns error changeset" do
      {:error, %Ecto.Changeset{}} = Events.create_activity_leader(%{})
    end

    test "create_activity_leader/1 disallows event owner as leader" do
      user = user_fixture()
      event = event_fixture(%{user: user})

      attrs = %{
        email: user.email,
        event_id: event.id,
        user_email: user.email
      }

      {:error, %Ecto.Changeset{}} = Events.create_activity_leader(attrs)
    end

    test "get_activity_leader!/1 gets activity leader by ID" do
      leader = activity_leader_fixture()
      assert Events.get_activity_leader!(leader.id) == leader
    end

    test "get_activity_leaders_for_event/1 gets activity leaders for event by ID", context do
      event = Enum.at(context.carol_active_events, 0)
      [leader] = Events.get_activity_leaders_for_event(event.id)
      assert leader.user_id == context.alice.id
    end

    test "change_activity_leader/2 returns an activity leader changeset" do
      leader = activity_leader_fixture()
      assert %Ecto.Changeset{} = Events.change_activity_leader(leader)
    end
  end

  describe "importing events" do
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
  end

  defp list(events), do: Enum.reverse(events)

  defp paginate(events, params \\ %{}) do
    page = Map.get(params, "page", 1)
    page_size = Map.get(params, "page_size", 5)
    start_index = (page - 1) * page_size
    event_count = length(events)

    {
      events |> Enum.reverse() |> Enum.slice(start_index, page_size),
      event_count,
      ceil(event_count / page_size)
    }
  end
end
