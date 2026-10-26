defmodule ClaperWeb.EventLive.VoteReplayTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PollsFixtures
  import Claper.PresentationsFixtures
  import Claper.QuizzesFixtures

  setup [:register_and_log_in_user]

  test "registered and anonymous poll replays stay connected without extra votes", %{
    conn: conn,
    user: user
  } do
    presentation = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation})
    poll = poll_fixture(%{presentation_file_id: presentation.id, multiple: true})

    anonymous_identifier = "poll-replay-attendee"

    anonymous_conn =
      build_conn() |> init_test_session(%{attendee_identifier: anonymous_identifier})

    for attendee_conn <- [conn, anonymous_conn] do
      audits_before = length(submission_audits("poll", poll.id))
      {:ok, view, _} = live(attendee_conn, ~p"/e/#{presentation.event.code}")
      render_hook(view, "select-poll-opt", %{"opt" => "0"})
      render_hook(view, "vote", %{})
      assert has_element?(view, "[data-submitted]")
      assert length(submission_audits("poll", poll.id)) == audits_before

      render_hook(view, "select-poll-opt", %{"opt" => "1"})

      for _attempt <- 1..2 do
        render_hook(view, "vote", %{})
        assert length(submission_audits("poll", poll.id)) == audits_before
      end

      render_hook(view, "vote", %{})
      assert length(submission_audits("poll", poll.id)) == audits_before + 1
      render_hook(view, "vote", %{})
      assert length(submission_audits("poll", poll.id)) == audits_before + 1
      assert has_element?(view, "[data-submitted]")
    end

    assert [2, 0] == Enum.map(Claper.Polls.get_poll!(poll.id).poll_opts, & &1.vote_count)

    audits = submission_audits("poll", poll.id)
    assert length(audits) == 2
    assert Enum.any?(audits, &(&1.user_id == user.id))
    assert anonymous_audit = Enum.find(audits, &is_nil(&1.user_id))
    assert is_binary(anonymous_audit.metadata["attendee_fingerprint"])

    for audit <- audits do
      assert audit.metadata["reason"] == "already_voted"
      assert audit.metadata["observed_count"] == 3
      assert audit.metadata["event_id"] == presentation.event.id
      metadata = Jason.encode!(audit.metadata)
      refute metadata =~ anonymous_identifier
      refute metadata =~ "some option"
      refute Map.has_key?(audit.metadata, "selected_poll_opt")
    end
  end

  test "malformed poll option indexes do not crash or create ballots", %{conn: conn, user: user} do
    presentation = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation})
    poll = poll_fixture(%{presentation_file_id: presentation.id})
    {:ok, view, _} = live(conn, ~p"/e/#{presentation.event.code}")

    for option <- ["-1", "not-an-index", "999", 0] do
      render_hook(view, "select-poll-opt", %{"opt" => option})
      render_hook(view, "vote", %{})
      assert has_element?(view, "#poll-opt-0")
    end

    assert Claper.Polls.get_poll_vote(user.id, poll.id) == []
    assert [audit] = submission_audits("poll", poll.id)
    assert audit.user_id == user.id
    assert audit.metadata["reason"] == "invalid_options"
    assert audit.metadata["observed_count"] == 3
    refute Jason.encode!(audit.metadata) =~ "not-an-index"
  end

  test "quiz replays do not inflate responses or crash the attendee LiveView", %{
    conn: conn,
    user: user
  } do
    presentation = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation})

    quiz =
      quiz_fixture(%{
        presentation_file: presentation,
        position: 0,
        enabled: true,
        allow_anonymous: true
      })

    [question] = quiz.quiz_questions
    [first, second] = question.quiz_question_opts

    anonymous_identifier = "quiz-replay-attendee"

    anonymous_conn =
      build_conn() |> init_test_session(%{attendee_identifier: anonymous_identifier})

    for attendee_conn <- [conn, anonymous_conn] do
      audits_before = length(submission_audits("quiz", quiz.id))
      {:ok, view, _} = live(attendee_conn, ~p"/e/#{presentation.event.code}")

      replay_views =
        for _tab <- 1..3 do
          {:ok, replay_view, _} = live(attendee_conn, ~p"/e/#{presentation.event.code}")
          render_hook(replay_view, "select-quiz-question-opt", %{"opt" => "#{second.id}"})
          replay_view
        end

      render_hook(view, "select-quiz-question-opt", %{"opt" => "#{first.id}"})
      render_hook(view, "submit-quiz", %{})
      assert length(submission_audits("quiz", quiz.id)) == audits_before

      for {replay_view, attempt} <- Enum.with_index(replay_views, 1) do
        render_hook(replay_view, "submit-quiz", %{})
        expected_audits = if attempt == 3, do: audits_before + 1, else: audits_before
        assert length(submission_audits("quiz", quiz.id)) == expected_audits
        assert render(replay_view) =~ "Waiting for results"
      end

      render_hook(view, "select-quiz-question-opt", %{"opt" => "#{second.id}"})
      render_hook(view, "submit-quiz", %{})
      assert render(view) =~ "Waiting for results"
    end

    updated = Claper.Quizzes.get_quiz!(quiz.id, quiz_questions: :quiz_question_opts)
    assert [2, 0] == Enum.map(hd(updated.quiz_questions).quiz_question_opts, & &1.response_count)
    assert Claper.Quizzes.get_submission_count(quiz.id) == 2

    audits = submission_audits("quiz", quiz.id)
    assert length(audits) == 2
    assert Enum.any?(audits, &(&1.user_id == user.id))
    assert anonymous_audit = Enum.find(audits, &is_nil(&1.user_id))
    assert is_binary(anonymous_audit.metadata["attendee_fingerprint"])

    for audit <- audits do
      assert audit.metadata["reason"] == "already_submitted"
      assert audit.metadata["observed_count"] == 3
      assert audit.metadata["event_id"] == presentation.event.id
      metadata = Jason.encode!(audit.metadata)
      refute metadata =~ anonymous_identifier
      refute metadata =~ "option 1"
      refute metadata =~ "option 2"
      refute Map.has_key?(audit.metadata, "selected_quiz_question_opts")
    end
  end

  defp submission_audits(resource_type, resource_id) do
    {logs, _meta} =
      Claper.Audit.list_logs(%{
        filters: [%{field: :action, op: :==, value: "security.suspicious_submission"}]
      })

    Enum.filter(logs, &(&1.resource_type == resource_type && &1.resource_id == resource_id))
  end
end
