defmodule Claper.InteractionsTest do
  use Claper.DataCase

  alias Claper.Interactions
  alias Claper.WordClouds.WordCloud

  import Claper.{
    EventsFixtures,
    PollsFixtures,
    PresentationsFixtures,
    QuizzesFixtures,
    WordCloudsFixtures
  }

  describe "move_interaction/3" do
    setup do
      event = event_fixture()
      presentation_file = presentation_file_fixture(%{event: event, length: 5})

      %{event: %{event | presentation_file: presentation_file}}
    end

    test "moves an interaction to another slide and disables it", %{event: event} do
      poll =
        poll_fixture(%{
          presentation_file_id: event.presentation_file.id,
          position: 0,
          enabled: true
        })

      assert {:ok, moved} = Interactions.move_interaction(event, poll, 3)
      assert moved.position == 3
      refute moved.enabled
      refute Claper.Polls.get_poll!(poll.id).enabled
    end

    test "moves a quiz without touching its questions", %{event: event} do
      quiz =
        quiz_fixture(%{
          presentation_file: event.presentation_file,
          position: 1,
          enabled: true
        })

      # Load through the same path as the manage LiveView: no preloads, so
      # quiz_questions is NotLoaded and must not be required by the update.
      quiz = Claper.Quizzes.get_quiz_for_event(quiz.id, event.id)

      assert {:ok, moved} = Interactions.move_interaction(event, quiz, 4)
      assert moved.position == 4
      refute moved.enabled
      assert length(Claper.Quizzes.get_quiz!(quiz.id, [:quiz_questions]).quiz_questions) == 1
    end

    test "is a no-op when the position is unchanged", %{event: event} do
      poll =
        poll_fixture(%{
          presentation_file_id: event.presentation_file.id,
          position: 2,
          enabled: true
        })

      assert {:ok, same} = Interactions.move_interaction(event, poll, 2)
      assert same.position == 2
      assert same.enabled
    end

    test "rejects out-of-range positions", %{event: event} do
      poll = poll_fixture(%{presentation_file_id: event.presentation_file.id, position: 0})

      assert {:error, :invalid_position} = Interactions.move_interaction(event, poll, -1)
      assert {:error, :invalid_position} = Interactions.move_interaction(event, poll, 5)
    end

    test "moves a word cloud to another slide and disables it", %{event: event} do
      word_cloud =
        word_cloud_fixture(%{presentation_file: event.presentation_file, position: 0})

      assert {:ok, moved} = Interactions.move_interaction(event, word_cloud, 2)
      assert moved.position == 2
      refute moved.enabled
    end
  end

  describe "word clouds among the interactions" do
    setup do
      event = event_fixture()
      presentation_file = presentation_file_fixture(%{event: event, length: 5})

      %{event: %{event | presentation_file: presentation_file}}
    end

    test "are listed at their position and counted", %{event: event} do
      word_cloud = word_cloud_fixture(%{presentation_file: event.presentation_file})
      poll_fixture(%{presentation_file_id: event.presentation_file.id, position: 0})

      assert {:ok, interactions} = Interactions.get_interactions_at_position(event, 0)
      assert Enum.any?(interactions, &match?(%WordCloud{id: id} when id == word_cloud.id, &1))
      assert Interactions.get_number_total_interactions(event.presentation_file.id) == 2
    end

    test "enabling a poll disables a word cloud on the same slide", %{event: event} do
      word_cloud =
        word_cloud_fixture(%{presentation_file: event.presentation_file, enabled: true})

      poll =
        poll_fixture(%{
          presentation_file_id: event.presentation_file.id,
          position: 0,
          enabled: false
        })

      assert :ok = Interactions.enable_interaction(poll)
      refute Claper.WordClouds.get_word_cloud!(word_cloud.id).enabled
      assert Claper.Polls.get_poll!(poll.id).enabled
    end

    test "enabling a word cloud disables a poll on the same slide", %{event: event} do
      poll =
        poll_fixture(%{
          presentation_file_id: event.presentation_file.id,
          position: 0,
          enabled: true
        })

      word_cloud =
        word_cloud_fixture(%{presentation_file: event.presentation_file, enabled: false})

      assert :ok = Interactions.enable_interaction(word_cloud)
      assert Claper.WordClouds.get_word_cloud!(word_cloud.id).enabled
      refute Claper.Polls.get_poll!(poll.id).enabled

      assert {:ok, _} = Interactions.disable_interaction(word_cloud)
      refute Claper.WordClouds.get_word_cloud!(word_cloud.id).enabled
    end
  end
end
