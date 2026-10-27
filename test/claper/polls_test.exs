defmodule Claper.PollsTest do
  use Claper.DataCase

  alias Claper.Polls

  describe "polls" do
    alias Claper.Polls.Poll

    import Claper.{PollsFixtures, PresentationsFixtures}

    @invalid_attrs %{title: nil}

    test "list_polls/1 returns all polls from a presentation" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      polls = Polls.list_polls(presentation_file.id)
      assert [%Poll{} | _] = polls
      assert length(polls) == 1
      assert hd(polls).id == poll.id
    end

    test "list_polls_at_position/2 returns all polls from a presentation at a given position" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, position: 5})

      polls = Polls.list_polls_at_position(presentation_file.id, 5)
      assert [%Poll{} | _] = polls
      assert length(polls) == 1
      assert hd(polls).id == poll.id
      assert hd(polls).position == 5
    end

    test "get_poll!/1 returns the poll with given id" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{presentation_file_id: presentation_file.id})
        |> Claper.Polls.set_percentages()

      fetched_poll = Polls.get_poll!(poll.id)

      assert fetched_poll.id == poll.id
      assert fetched_poll.position == poll.position
      assert fetched_poll.poll_opts == poll.poll_opts
      assert fetched_poll.title == poll.title
    end

    test "create_poll/1 with valid data creates a poll" do
      presentation_file = presentation_file_fixture()

      valid_attrs = %{
        title: "some title",
        presentation_file_id: presentation_file.id,
        position: 0,
        poll_opts: [
          %{content: "some option 1", vote_count: 0},
          %{content: "some option 2", vote_count: 0}
        ]
      }

      assert {:ok, %Poll{} = poll} = Polls.create_poll(valid_attrs)
      assert poll.title == "some title"
    end

    test "create_poll/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Polls.create_poll(@invalid_attrs)
    end

    test "update_poll/3 with valid data updates the poll" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      update_attrs = %{title: "some updated title"}

      assert {:ok, %Poll{} = poll} =
               Polls.update_poll(presentation_file.event_id, poll, update_attrs)

      assert poll.title == "some updated title"
    end

    test "update_poll/3 with invalid data returns error changeset" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      assert {:error, %Ecto.Changeset{}} =
               Polls.update_poll(presentation_file.event_id, poll, @invalid_attrs)

      fetched_poll = Polls.get_poll!(poll.id)
      poll = poll |> Claper.Polls.set_percentages()

      assert fetched_poll.poll_opts == poll.poll_opts
      assert fetched_poll.poll_votes == poll.poll_votes
      assert fetched_poll.title == poll.title
    end

    test "delete_poll/2 deletes the poll" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      assert {:ok, %Poll{}} = Polls.delete_poll(presentation_file.event_id, poll)
      assert_raise Ecto.NoResultsError, fn -> Polls.get_poll!(poll.id) end
    end

    test "change_poll/1 returns a poll changeset" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      assert %Ecto.Changeset{} = Polls.change_poll(poll)
    end

    test "get_poll_for_event/2 returns poll when it belongs to the event" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      fetched_poll = Polls.get_poll_for_event(poll.id, presentation_file.event_id)
      assert fetched_poll.id == poll.id
    end

    test "get_poll_for_event/2 returns nil when poll belongs to a different event" do
      presentation_file_a = presentation_file_fixture()
      presentation_file_b = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file_a.id})

      assert is_nil(Polls.get_poll_for_event(poll.id, presentation_file_b.event_id))
    end

    test "get_poll_for_event/2 returns nil for nonexistent poll id" do
      presentation_file = presentation_file_fixture()
      assert is_nil(Polls.get_poll_for_event(-1, presentation_file.event_id))
    end
  end

  describe "poll_opts" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "add_poll_opt/1 returns poll changeset plus the added poll_opt" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      poll_changeset = poll |> Polls.change_poll()

      assert Ecto.Changeset.get_field(Polls.add_poll_opt(poll_changeset), :poll_opts)
             |> Enum.count() == 3
    end

    test "remove_poll_opt/2 returns poll changeset minus the removed poll_opt" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      poll_changeset = poll |> Polls.change_poll()

      assert Ecto.Changeset.get_field(
               Polls.remove_poll_opt(poll_changeset, Enum.at(poll.poll_opts, 0)),
               :poll_opts
             )
             |> Enum.count() == 1
    end
  end

  describe "poll_votes" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "get_poll_vote/2 returns the poll_vote with given id and user id" do
      poll_vote = poll_vote_fixture()
      assert Polls.get_poll_vote(poll_vote.user_id, poll_vote.poll_id) == [poll_vote]
    end

    test "vote/4 with valid data creates a poll_vote" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      [poll_opt | _] = poll.poll_opts

      assert {:ok, %Polls.Poll{}} =
               Polls.vote(
                 presentation_file.event.user_id,
                 presentation_file.event_id,
                 [poll_opt],
                 poll.id
               )
    end

    test "a ballot cannot be replayed with the same or different options" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, multiple: true})
      [first, second] = poll.poll_opts
      uuid = presentation_file.event.uuid
      Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{uuid}")

      for voter <- [
            Integer.to_string(presentation_file.event.user_id),
            presentation_file.event.user_id
          ] do
        assert {:ok, _} = Polls.vote(voter, uuid, [first], poll.id)
        assert_receive {:poll_updated, _}
        assert {:error, :already_voted} = Polls.vote(voter, uuid, [first], poll.id)
        assert {:error, :already_voted} = Polls.vote(voter, uuid, [second], poll.id)
        assert [%{poll_opt_id: id}] = Polls.get_poll_vote(voter, poll.id)
        assert id == first.id
        refute_receive {:poll_updated, _}
      end

      assert [2, 0] == Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.vote_count)
      assert Claper.Stats.get_distinct_poll_votes([poll.id]) == 2
      assert Claper.Stats.total_vote_count(presentation_file.id) == [2]
    end

    test "multiple-choice selections are one ballot and stale counters do not lose votes" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, multiple: true})
      [first, second] = poll.poll_opts
      uuid = presentation_file.event.uuid

      assert {:ok, _} = Polls.vote("first", uuid, [first, second, first], poll.id)
      assert {:ok, _} = Polls.vote("second", uuid, [first], poll.id)
      assert {:ok, _} = Polls.vote(presentation_file.event.user_id, uuid, [second], poll.id)
      assert length(Polls.get_poll_vote("first", poll.id)) == 2
      assert [2, 2] == Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.vote_count)
      assert {:error, :already_voted} = Polls.vote("first", uuid, [second], poll.id)
    end

    test "invalid choices and closed polls never persist a ballot" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      other = poll_fixture(%{presentation_file_id: presentation_file.id, enabled: false})
      uuid = presentation_file.event.uuid

      assert {:error, :invalid_options} = Polls.vote("attendee", uuid, [], poll.id)
      assert {:error, :invalid_options} = Polls.vote("attendee", uuid, poll.poll_opts, poll.id)
      assert {:error, :invalid_options} = Polls.vote("attendee", uuid, other.poll_opts, poll.id)
      assert {:error, :invalid_options} = Polls.vote("attendee", uuid, [nil], poll.id)
      assert {:error, :not_open} = Polls.vote("attendee", uuid, other.poll_opts, other.id)
      assert Polls.get_poll_vote("attendee", poll.id) == []
      assert [0, 0] == Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.vote_count)
    end
  end
end
