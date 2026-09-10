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
  end

  describe "slider polls" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "create_poll/1 accepts a slider poll without any pre-defined choice" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      assert poll.type == :slider
      assert poll.min_value == 1
      assert poll.max_value == 10
      assert poll.poll_opts == []
    end

    test "create_poll/1 rejects a range whose highest value is not above the lowest one" do
      presentation_file = presentation_file_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.create_poll(%{
                 title: "some title",
                 position: 0,
                 presentation_file_id: presentation_file.id,
                 type: :slider,
                 min_value: 5,
                 max_value: 5,
                 poll_opts: []
               })

      assert "must be greater than the lowest value" in errors_on(changeset).max_value
    end

    test "submit_rating/4 records a rating nobody picked yet as a new poll_opt" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      assert {:ok, %Polls.Poll{} = updated_poll} =
               Polls.submit_rating(
                 "attendee-1",
                 presentation_file.event.uuid,
                 poll.id,
                 "7"
               )

      assert [%{content: "7", vote_count: 1}] = updated_poll.poll_opts
    end

    test "submit_rating/4 increments a rating already picked instead of duplicating it" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "7")

      {:ok, updated_poll} =
        Polls.submit_rating("attendee-2", presentation_file.event.uuid, poll.id, "7")

      assert [%{content: "7", vote_count: 2}] = updated_poll.poll_opts
    end

    test "submit_rating/4 records a poll_vote, so the attendee cannot rate twice" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "7")

      assert [%Polls.PollVote{}] = Polls.get_poll_vote("attendee-1", poll.id)
    end

    test "submit_rating/4 with a value outside the poll's range returns an error" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      assert {:error, :out_of_range} =
               Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "42")

      assert {:error, :out_of_range} =
               Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "0")

      assert {:error, :out_of_range} =
               Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "seven")
    end

    test "average_rating/1 weights every value by the number of votes it got" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: [
            %{content: "2", vote_count: 1},
            %{content: "9", vote_count: 3}
          ]
        })

      assert Polls.average_rating(poll) == 7.3
    end

    test "average_rating/1 returns nil while nobody has rated yet" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      assert Polls.average_rating(poll) == nil
    end

    test "rating_distribution/1 covers the whole range and scales to the most picked value" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 3,
          poll_opts: [
            %{content: "1", vote_count: 1},
            %{content: "3", vote_count: 4}
          ]
        })

      assert [
               %{value: 1, vote_count: 1, percentage: 25},
               %{value: 2, vote_count: 0, percentage: 0},
               %{value: 3, vote_count: 4, percentage: 100}
             ] = Polls.rating_distribution(poll)
    end

    test "default_rating/1 starts the slider in the middle of the range" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 5,
          poll_opts: []
        })

      assert Polls.default_rating(poll) == 3
    end
  end

  describe "slider polls: one bucket per rating value" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    alias Claper.Polls.PollOpt

    test "the database keeps a single poll_opt per rating value of a poll" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      attrs = %{poll_id: poll.id, content: "7", rating_value: 7, vote_count: 1}

      assert {:ok, _opt} = %PollOpt{} |> PollOpt.rating_changeset(attrs) |> Repo.insert()

      assert {:error, changeset} = %PollOpt{} |> PollOpt.rating_changeset(attrs) |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).rating_value
    end

    test "submit_rating/4 stores the rating value on the bucket it creates" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, poll} =
        Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "7")

      assert [opt] = poll.poll_opts
      assert opt.content == "7"
      assert opt.rating_value == 7
      assert opt.vote_count == 1
    end

    test "submit_rating/4 counts into the existing bucket instead of adding a second one" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      event_uuid = presentation_file.event.uuid

      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "7")
      {:ok, _} = Polls.submit_rating("attendee-2", event_uuid, poll.id, "7")
      {:ok, poll} = Polls.submit_rating("attendee-3", event_uuid, poll.id, "7")

      assert [opt] = poll.poll_opts
      assert opt.content == "7"
      assert opt.rating_value == 7
      assert opt.vote_count == 3

      votes_of_this_poll =
        Repo.aggregate(
          from(v in Claper.Polls.PollVote, where: v.poll_id == ^poll.id),
          :count,
          :id
        )

      assert votes_of_this_poll == 3
    end
  end

  describe "slider polls: only sliders take ratings" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "submit_rating/4 refuses a choice poll instead of adding an option to it" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, type: :choice})

      assert {:error, :not_a_slider} =
               Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "7")

      refute "7" in Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.content)
      assert length(Polls.get_poll!(poll.id).poll_opts) == 2
      assert Polls.get_poll_vote("attendee-1", poll.id) == []
    end
  end

  describe "slider polls: only choice polls take option votes" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "vote/4 refuses a slider poll instead of counting into a rating bucket" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "7")
      buckets = Polls.get_poll!(poll.id).poll_opts

      assert {:error, :not_a_choice} =
               Polls.vote("attendee-2", presentation_file.event.uuid, buckets, poll.id)

      assert [%{content: "7", vote_count: 1}] = Polls.get_poll!(poll.id).poll_opts
      assert Polls.get_poll_vote("attendee-2", poll.id) == []
    end

    test "vote/4 refuses a slider poll that has no bucket at all" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      # what the "vote" handler builds when nobody has rated yet:
      # Enum.at([], 0) is nil
      assert {:error, :not_a_choice} =
               Polls.vote("attendee-1", presentation_file.event.uuid, [nil], poll.id)

      assert Polls.get_poll!(poll.id).poll_opts == []
      assert Polls.get_poll_vote("attendee-1", poll.id) == []
    end

    test "vote/4 refuses an option that is not one of the poll's own" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, type: :choice})
      other_poll = poll_fixture(%{presentation_file_id: presentation_file.id, position: 1})

      assert {:error, :unknown_poll_opt} =
               Polls.vote("attendee-1", presentation_file.event.uuid, [nil], poll.id)

      assert {:error, :unknown_poll_opt} =
               Polls.vote(
                 "attendee-1",
                 presentation_file.event.uuid,
                 [hd(other_poll.poll_opts)],
                 poll.id
               )

      assert Polls.get_poll_vote("attendee-1", poll.id) == []
      assert Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.vote_count) == [0, 0]
    end
  end

  describe "slider polls: one rating per attendee" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    setup do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      %{event_uuid: presentation_file.event.uuid, poll: poll}
    end

    test "submit_rating/4 refuses a second rating from the same attendee", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "7")

      assert {:error, :already_voted} =
               Polls.submit_rating("attendee-1", event_uuid, poll.id, "3")

      assert [%{content: "7", vote_count: 1}] = Polls.get_poll!(poll.id).poll_opts
      assert length(Polls.get_poll_vote("attendee-1", poll.id)) == 1
    end

    test "submit_rating/4 refuses the very same rating twice as well", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "7")

      assert {:error, :already_voted} =
               Polls.submit_rating("attendee-1", event_uuid, poll.id, "7")

      assert [%{vote_count: 1}] = Polls.get_poll!(poll.id).poll_opts
      assert Polls.average_rating(Polls.get_poll!(poll.id)) == 7.0
    end

    test "submit_rating/4 refuses a second rating from the same signed-in user", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      user = Claper.AccountsFixtures.user_fixture()

      {:ok, _} = Polls.submit_rating(user.id, event_uuid, poll.id, "7")

      assert {:error, :already_voted} = Polls.submit_rating(user.id, event_uuid, poll.id, "2")

      assert length(Polls.get_poll_vote(user.id, poll.id)) == 1
    end
  end

  describe "a poll_opt's rating value is not the form's to set" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "create_poll/1 ignores a rating_value sent with the choices" do
      presentation_file = presentation_file_fixture()

      assert {:ok, poll} =
               Polls.create_poll(%{
                 "title" => "some title",
                 "position" => 0,
                 "presentation_file_id" => presentation_file.id,
                 "type" => "choice",
                 "poll_opts" => %{
                   "0" => %{"content" => "yes", "rating_value" => "7"},
                   "1" => %{"content" => "no", "rating_value" => "7"}
                 }
               })

      assert Enum.map(poll.poll_opts, & &1.content) == ["yes", "no"]
      assert Enum.map(poll.poll_opts, & &1.rating_value) == [nil, nil]
    end

    test "update_poll/3 ignores a rating_value sent with the choices" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, type: :choice})
      [first, second] = poll.poll_opts

      assert {:ok, _updated} =
               Polls.update_poll(presentation_file.event.uuid, poll, %{
                 "poll_opts" => %{
                   "0" => %{"id" => "#{first.id}", "content" => "yes", "rating_value" => "7"},
                   "1" => %{"id" => "#{second.id}", "content" => "no", "rating_value" => "7"}
                 }
               })

      assert Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.rating_value) == [nil, nil]
    end
  end

  describe "narrowing a slider poll's range" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    setup do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      %{event_uuid: presentation_file.event.uuid, poll: poll}
    end

    test "update_poll/3 refuses a range that would leave submitted ratings outside it", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "8")
      poll = Polls.get_poll!(poll.id)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.update_poll(event_uuid, poll, %{
                 "type" => "slider",
                 "min_value" => "1",
                 "max_value" => "5"
               })

      assert "cannot leave out ratings that have already been submitted" in errors_on(changeset).max_value

      # the refused change keeps both the range and the ratings as they were
      poll = Polls.get_poll!(poll.id)
      assert poll.max_value == 10
      assert Enum.map(poll.poll_opts, & &1.rating_value) == [8]
      assert Polls.average_rating(poll) == 8.0
    end

    test "update_poll/3 refuses raising the lowest value above a submitted rating", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "2")
      poll = Polls.get_poll!(poll.id)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.update_poll(event_uuid, poll, %{
                 "type" => "slider",
                 "min_value" => "4",
                 "max_value" => "10"
               })

      assert "cannot leave out ratings that have already been submitted" in errors_on(changeset).min_value

      assert Polls.get_poll!(poll.id).min_value == 1
    end

    test "update_poll/3 allows a narrower range that still covers every rating", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "3")
      poll = Polls.get_poll!(poll.id)

      assert {:ok, updated} =
               Polls.update_poll(event_uuid, poll, %{
                 "type" => "slider",
                 "min_value" => "1",
                 "max_value" => "5"
               })

      assert updated.max_value == 5
      assert Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.rating_value) == [3]
    end

    test "update_poll/3 allows narrowing a range nobody has rated in yet", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      assert {:ok, updated} =
               Polls.update_poll(event_uuid, poll, %{
                 "type" => "slider",
                 "min_value" => "2",
                 "max_value" => "4"
               })

      assert updated.min_value == 2
      assert updated.max_value == 4
    end

    test "update_poll/3 still drops the ratings when the poll stops being a slider", %{
      event_uuid: event_uuid,
      poll: poll
    } do
      {:ok, _} = Polls.submit_rating("attendee-1", event_uuid, poll.id, "8")
      poll = Polls.get_poll!(poll.id)

      assert {:ok, updated} =
               Polls.update_poll(event_uuid, poll, %{
                 "type" => "choice",
                 "min_value" => "1",
                 "max_value" => "5",
                 "poll_opts" => %{"0" => %{"content" => "yes"}}
               })

      assert updated.type == :choice
      assert Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.content) == ["yes"]
    end
  end

  describe "poll ranges" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    alias Claper.Polls.Poll

    test "create_poll/1 rejects a reversed range on a choice poll too" do
      presentation_file = presentation_file_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.create_poll(%{
                 title: "some title",
                 position: 0,
                 presentation_file_id: presentation_file.id,
                 type: :choice,
                 min_value: 99,
                 max_value: 3,
                 poll_opts: [%{content: "some option 1", vote_count: 0}]
               })

      assert "must be greater than the lowest value" in errors_on(changeset).max_value
    end

    test "create_poll/1 rejects a range outside the supported bounds on a choice poll too" do
      presentation_file = presentation_file_fixture()

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.create_poll(%{
                 title: "some title",
                 position: 0,
                 presentation_file_id: presentation_file.id,
                 type: :choice,
                 min_value: 1,
                 max_value: 4200,
                 poll_opts: [%{content: "some option 1", vote_count: 0}]
               })

      assert errors_on(changeset).max_value != []
    end

    test "the database refuses a reversed range even when the changeset is bypassed" do
      presentation_file = presentation_file_fixture()

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%Poll{
          title: "some title",
          position: 0,
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 99,
          max_value: 3
        })
      end
    end
  end

  describe "switching a poll's type" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "update_poll/3 drops the old choices when a choice poll becomes a slider" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, type: :choice})

      # exactly what the edit form sends while the slider branch is on screen:
      # no "poll_opts" key at all
      assert {:ok, updated} =
               Polls.update_poll(presentation_file.event.uuid, poll, %{
                 "title" => "rate it!",
                 "type" => "slider",
                 "min_value" => "1",
                 "max_value" => "10"
               })

      assert updated.type == :slider
      assert Polls.get_poll!(poll.id).poll_opts == []
    end

    test "update_poll/3 does not turn attendees' ratings into the choices of a choice poll" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "5")
      {:ok, _} = Polls.submit_rating("attendee-2", presentation_file.event.uuid, poll.id, "8")

      # the edit form works on the poll as it comes out of the database, with
      # the rating buckets loaded, and sends no "poll_opts" key while the slider
      # branch is on screen
      poll = Polls.get_poll!(poll.id)

      assert {:error, %Ecto.Changeset{} = changeset} =
               Polls.update_poll(presentation_file.event.uuid, poll, %{
                 "title" => "rate it!",
                 "type" => "choice"
               })

      assert "can't be blank" in errors_on(changeset).poll_opts

      # the failed switch leaves the poll and its ratings untouched
      poll = Polls.get_poll!(poll.id)
      assert poll.type == :slider
      assert Enum.map(poll.poll_opts, & &1.content) == ["5", "8"]
    end

    test "update_poll/3 replaces the ratings with the new choices when both are given" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_rating("attendee-1", presentation_file.event.uuid, poll.id, "5")

      assert {:ok, updated} =
               Polls.update_poll(presentation_file.event.uuid, poll, %{
                 "title" => "pick one",
                 "type" => "choice",
                 "poll_opts" => %{
                   "0" => %{"content" => "yes"},
                   "1" => %{"content" => "no"}
                 }
               })

      assert updated.type == :choice
      assert Enum.map(Polls.get_poll!(updated.id).poll_opts, & &1.content) == ["yes", "no"]
      assert Polls.get_poll_vote("attendee-1", poll.id) == []
    end

    test "update_poll/3 never saves multiple answers on a slider poll" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :slider,
          min_value: 1,
          max_value: 10,
          poll_opts: []
        })

      assert {:ok, updated} =
               Polls.update_poll(presentation_file.event.uuid, poll, %{
                 "title" => "rate it!",
                 "type" => "slider",
                 "multiple" => "true"
               })

      assert updated.multiple == false
    end
  end
end
