defmodule Claper.VoteConcurrencyTest do
  use Claper.DataCase

  import Claper.AccountsFixtures
  import Claper.PollsFixtures
  import Claper.PresentationsFixtures
  import Claper.QuizzesFixtures

  alias Claper.{Polls, Quizzes}
  alias Ecto.Adapters.SQL.Sandbox

  setup do
    # Real, separate connections are required: shared sandbox tasks would serialize
    # all transactions on one connection and cannot exercise unique-index races.
    data =
      Sandbox.unboxed_run(Repo, fn ->
        user = user_fixture()
        presentation = presentation_file_fixture(%{user: user}, [:event])
        poll = poll_fixture(%{presentation_file_id: presentation.id, multiple: true})
        quiz = quiz_fixture(%{presentation_file: presentation, enabled: true})
        %{user: user, event: presentation.event, poll: poll, quiz: quiz}
      end)

    on_exit(fn ->
      Sandbox.unboxed_run(Repo, fn ->
        Repo.delete!(data.event)
        Repo.delete!(data.user)
      end)
    end)

    data
  end

  test "concurrent anonymous and registered poll replays persist only one complete ballot",
       data do
    [first, second] = data.poll.poll_opts

    for identity <- ["concurrent-attendee", data.user.id] do
      results =
        race(fn index ->
          options = if rem(index, 2) == 0, do: [first, second], else: [second]
          Polls.vote(identity, data.event.uuid, options, data.poll.id)
        end)

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &(&1 == {:error, :already_voted})) == 7
    end

    Sandbox.unboxed_run(Repo, fn ->
      votes = Repo.all(from v in Polls.PollVote, where: v.poll_id == ^data.poll.id)
      updated = Polls.get_poll!(data.poll.id)

      for option <- updated.poll_opts do
        assert option.vote_count == Enum.count(votes, &(&1.poll_opt_id == option.id))
      end

      assert Enum.at(updated.poll_opts, 1).vote_count == 2
    end)
  end

  test "distinct participants concurrently voting from stale structs do not lose increments",
       data do
    [option | _] = data.poll.poll_opts

    assert race(fn index ->
             Polls.vote("independent-#{index}", data.event.uuid, [option], data.poll.id)
           end)
           |> Enum.all?(&match?({:ok, _}, &1))

    Sandbox.unboxed_run(Repo, fn ->
      assert hd(Polls.get_poll!(data.poll.id).poll_opts).vote_count == 8
    end)
  end

  test "concurrent quiz replays and independent submissions preserve exact distributions", data do
    [question] = data.quiz.quiz_questions
    [first, second] = question.quiz_question_opts

    for participant <- ["concurrent-quiz-attendee", data.user] do
      results =
        race(fn index ->
          options = if rem(index, 2) == 0, do: [first, second], else: [second]
          Quizzes.submit_quiz(participant, data.event.uuid, options, data.quiz.id)
        end)

      assert Enum.count(results, &match?({:ok, _}, &1)) == 1
      assert Enum.count(results, &(&1 == {:error, :already_submitted})) == 7
    end

    assert race(fn index ->
             Quizzes.submit_quiz("independent-#{index}", data.event.uuid, [first], data.quiz.id)
           end)
           |> Enum.all?(&match?({:ok, _}, &1))

    Sandbox.unboxed_run(Repo, fn ->
      responses = Repo.all(from r in Quizzes.QuizResponse, where: r.quiz_id == ^data.quiz.id)
      quiz = Quizzes.get_quiz!(data.quiz.id, quiz_questions: :quiz_question_opts)
      [updated_question] = quiz.quiz_questions

      for option <- updated_question.quiz_question_opts do
        assert option.response_count ==
                 Enum.count(responses, &(&1.quiz_question_opt_id == option.id))
      end

      assert Enum.at(updated_question.quiz_question_opts, 1).response_count == 2
      assert Quizzes.get_submission_count(data.quiz.id) == 10
    end)
  end

  defp race(fun) do
    parent = self()
    barrier = make_ref()

    tasks =
      for index <- 1..8 do
        Task.async(fn -> await_race(parent, barrier, index, fun) end)
      end

    for _ <- tasks do
      assert_receive {:ready, ^barrier, _pid}, 5_000
    end

    Enum.each(tasks, &send(&1.pid, {:go, barrier}))
    Enum.map(tasks, &Task.await(&1, 15_000))
  end

  defp await_race(parent, barrier, index, fun) do
    send(parent, {:ready, barrier, self()})

    receive do
      {:go, ^barrier} -> Sandbox.unboxed_run(Repo, fn -> fun.(index) end)
    end
  end
end
