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

  describe "word cloud polls" do
    import Claper.{PollsFixtures, PresentationsFixtures}

    test "submit_word/4 creates a new poll_opt for a word not seen before" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      assert {:ok, %Polls.Poll{} = updated_poll} =
               Polls.submit_word(
                 "attendee-1",
                 presentation_file.event_id,
                 poll.id,
                 "great"
               )

      assert [%{content: "great", vote_count: 1}] = updated_poll.poll_opts
    end

    test "submit_word/4 merges a repeated word case-insensitively instead of duplicating it" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "Great")

      {:ok, updated_poll} =
        Polls.submit_word("attendee-2", presentation_file.event_id, poll.id, "great")

      assert [%{content: "Great", vote_count: 2}] = updated_poll.poll_opts
    end

    test "submit_word/4 stores a normalized key next to the word it was typed as" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, updated_poll} =
        Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "  Banana ")

      assert [%{content: "Banana", normalized_content: "banana", vote_count: 1}] =
               updated_poll.poll_opts
    end

    test "the database refuses a second row for a word a cloud already holds" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      {:ok, _} = Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "Banana")

      # The row a second attendee's submission would write if it slipped past
      # the lookup at the very same moment. The sandbox runs every process on
      # one connection, so this is what the index does, not a race actually run.
      racing_insert = """
      INSERT INTO poll_opts (content, normalized_content, vote_count, poll_id, inserted_at, updated_at)
      SELECT content, normalized_content, 1, poll_id, now(), now()
      FROM poll_opts WHERE poll_id = $1
      """

      assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
               Repo.query(racing_insert, [poll.id])
    end

    test "submit_word/4 counts the word the loser of a race wrote instead of adding its own" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      # The row a submission that won the race left behind while this one was
      # still on its way to the database.
      {:ok, _} =
        Repo.query(
          """
          INSERT INTO poll_opts (content, normalized_content, vote_count, poll_id, inserted_at, updated_at)
          VALUES ('Banana', 'banana', 1, $1, now(), now())
          """,
          [poll.id]
        )

      assert {:ok, updated_poll} =
               Polls.submit_word("attendee-2", presentation_file.event_id, poll.id, "banana")

      assert [%{content: "Banana", vote_count: 2}] = updated_poll.poll_opts
    end

    test "submit_word/4 refuses a poll that is not a word cloud" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id, type: :choice})

      assert {:error, :not_an_open_word_cloud} =
               Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "great")

      assert Enum.map(Polls.get_poll!(poll.id).poll_opts, & &1.content) == [
               "some option 1",
               "some option 2"
             ]

      assert Repo.aggregate(from(v in Polls.PollVote, where: v.poll_id == ^poll.id), :count) == 0
    end

    test "submit_word/4 refuses a word cloud that is not enabled" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          enabled: false,
          poll_opts: []
        })

      assert {:error, :not_an_open_word_cloud} =
               Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "great")

      assert Polls.get_poll!(poll.id).poll_opts == []
    end

    test "submit_word/4 refuses a poll id that belongs to no poll at all" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      assert {:error, :not_an_open_word_cloud} =
               Polls.submit_word("attendee-1", presentation_file.event_id, -1, "great")
    end

    test "update_poll/3 drops the choices a poll no longer uses when it becomes a word cloud" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})

      assert length(poll.poll_opts) == 2

      assert {:ok, updated_poll} =
               Polls.update_poll(presentation_file.event_id, poll, %{"type" => "word_cloud"})

      assert updated_poll.type == :word_cloud
      assert updated_poll.poll_opts == []
      assert Polls.get_poll!(poll.id).poll_opts == []
    end

    test "update_poll/3 keeps the submitted words when a word cloud is edited" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 3}]
        })

      assert {:ok, updated_poll} =
               Polls.update_poll(presentation_file.event_id, poll, %{
                 "title" => "How do you feel now?",
                 "type" => "word_cloud"
               })

      assert updated_poll.title == "How do you feel now?"
      assert [%{content: "tired", vote_count: 3}] = Polls.get_poll!(poll.id).poll_opts
    end

    test "create_poll/1 creates a word cloud without options when the type arrives as a string" do
      presentation_file = presentation_file_fixture()

      attrs = %{
        "title" => "One word for today?",
        "presentation_file_id" => presentation_file.id,
        "position" => 0,
        "type" => "word_cloud"
      }

      assert {:ok, %Polls.Poll{} = poll} = Polls.create_poll(attrs)
      assert poll.type == :word_cloud
      assert Polls.get_poll!(poll.id).poll_opts == []
    end

    test "create_poll/1 still requires options for a choice poll when the type arrives as a string" do
      presentation_file = presentation_file_fixture()

      attrs = %{
        "title" => "Pick one",
        "presentation_file_id" => presentation_file.id,
        "position" => 0,
        "type" => "choice"
      }

      assert {:error, changeset} = Polls.create_poll(attrs)
      assert %{poll_opts: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_poll/3 ignores poll_opts a form submits for a word cloud" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 2}]
        })

      [word] = poll.poll_opts

      assert {:ok, _} =
               Polls.update_poll(presentation_file.event_id, poll, %{
                 "title" => "How do you feel now?",
                 "poll_opts" => %{
                   "0" => %{"id" => to_string(word.id), "content" => "exhausted"}
                 }
               })

      assert [%{content: "tired", normalized_content: "tired", vote_count: 2}] =
               Polls.get_poll!(poll.id).poll_opts
    end

    test "create_poll/1 ignores poll_opts submitted along with a word cloud" do
      presentation_file = presentation_file_fixture()

      assert {:ok, poll} =
               Polls.create_poll(%{
                 "title" => "One word for today?",
                 "presentation_file_id" => presentation_file.id,
                 "position" => 0,
                 "type" => "word_cloud",
                 "poll_opts" => %{"0" => %{"content" => "planted"}}
               })

      assert Polls.get_poll!(poll.id).poll_opts == []
    end

    test "update_poll/3 refuses to turn a word cloud that holds words into a choice poll" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 2}]
        })

      assert {:error, changeset} =
               Polls.update_poll(presentation_file.event_id, poll, %{
                 "type" => "choice",
                 "poll_opts" => %{"0" => %{"content" => "Yes"}}
               })

      assert %{type: ["cannot be changed once this poll has been answered" <> _]} =
               errors_on(changeset)

      saved = Polls.get_poll!(poll.id)
      assert saved.type == :word_cloud
      assert [%{content: "tired", vote_count: 2}] = saved.poll_opts
    end

    test "update_poll/3 refuses to turn an answered choice poll into a word cloud" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      [poll_opt | _] = poll.poll_opts

      {:ok, _} =
        Polls.vote(
          presentation_file.event.user_id,
          presentation_file.event_id,
          [poll_opt],
          poll.id
        )

      assert {:error, changeset} =
               Polls.update_poll(presentation_file.event_id, poll, %{"type" => "word_cloud"})

      assert %{type: ["cannot be changed once this poll has been answered" <> _]} =
               errors_on(changeset)

      saved = Polls.get_poll!(poll.id)
      assert saved.type == :choice
      assert length(saved.poll_opts) == 2
      assert Repo.aggregate(from(v in Polls.PollVote, where: v.poll_id == ^poll.id), :count) == 1
    end

    test "update_poll/3 leaves an answered poll editable as long as the type stays put" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 2}]
        })

      assert {:ok, updated} =
               Polls.update_poll(presentation_file.event_id, poll, %{
                 "title" => "How do you feel now?",
                 "type" => "word_cloud"
               })

      assert updated.title == "How do you feel now?"
      assert [%{content: "tired", vote_count: 2}] = Polls.get_poll!(poll.id).poll_opts
    end

    test "change_poll/2 shows the refusal while the presenter is still in the form" do
      presentation_file = presentation_file_fixture()

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 1}]
        })

      changeset = Polls.change_poll(poll, %{"type" => "choice"})

      assert %{type: ["cannot be changed once this poll has been answered" <> _]} =
               errors_on(changeset)

      assert Polls.change_poll(poll).errors == []
    end

    test "submit_word/4 with a blank word returns an error changeset" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: []
        })

      assert {:error, %Ecto.Changeset{}} =
               Polls.submit_word("attendee-1", presentation_file.event_id, poll.id, "   ")
    end
  end

  describe "the word cloud match key" do
    alias Claper.Polls.PollOpt

    import Claper.{PollsFixtures, PresentationsFixtures}

    test "normalize/1 folds case for letters outside ASCII" do
      # SQL lower() folds these by the database collation, so a C-collation
      # database would leave "ÄRGER" as it stands and the migration would write
      # a key the application never computes.
      assert PollOpt.normalize("ÄRGER") == "ärger"
    end

    test "normalize/1 trims the whitespace SQL btrim() leaves in place" do
      # A no-break space and an em space, the kind a phone keyboard or a paste
      # from a slide brings along. btrim() strips neither.
      assert PollOpt.normalize("\u00A0banana\u2003") == "banana"
      assert PollOpt.normalize("  banana  ") == "banana"
    end

    test "normalize/1 cuts the key at the length submit_word/4 stores" do
      long = String.duplicate("a", 80)

      assert PollOpt.normalize(long) == String.duplicate("a", 60)
      assert String.length(PollOpt.word(long)) == 60
    end

    test "changeset/2 rewrites the key of a word whose content is rewritten" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "Banana", vote_count: 1}]
        })

      [word] = poll.poll_opts
      assert word.normalized_content == "banana"

      changeset = PollOpt.changeset(word, %{"content" => "ÄRGER"})

      assert Ecto.Changeset.get_change(changeset, :normalized_content) == "ärger"
    end

    test "changeset/2 leaves a choice option without a key" do
      presentation_file = presentation_file_fixture()
      poll = poll_fixture(%{presentation_file_id: presentation_file.id})
      [option | _] = poll.poll_opts

      assert option.normalized_content == nil

      changeset = PollOpt.changeset(option, %{"content" => "Maybe"})

      assert Ecto.Changeset.get_field(changeset, :normalized_content) == nil
    end

    test "every word a cloud holds carries a key" do
      presentation_file = presentation_file_fixture(%{}, [:event])

      poll =
        poll_fixture(%{
          presentation_file_id: presentation_file.id,
          type: :word_cloud,
          poll_opts: [%{content: "tired", vote_count: 2}, %{content: "Awake", vote_count: 1}]
        })

      keys = Polls.get_poll!(poll.id).poll_opts |> Enum.map(& &1.normalized_content)

      assert keys == ["tired", "awake"]
    end
  end
end
