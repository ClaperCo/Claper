defmodule Claper.VoteMigrationTest do
  use Claper.DataCase

  unless Code.ensure_loaded?(Claper.Repo.Migrations.EnforceUniqueBallotsAndQuizResponses) do
    Code.require_file(
      Path.expand(
        "../../priv/repo/migrations/20261025160002_enforce_unique_ballots_and_quiz_responses.exs",
        __DIR__
      )
    )
  end

  alias Claper.Repo.Migrations.EnforceUniqueBallotsAndQuizResponses, as: Migration

  setup do
    # Exercise the real migration in an isolated, transaction-local search path.
    # No public application tables or migration versions are altered.
    schema = "ballot_migration_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE SCHEMA #{schema}")
    Repo.query!("SET LOCAL search_path TO #{schema}")

    for sql <- [
          "CREATE TABLE users (id bigint PRIMARY KEY)",
          "CREATE TABLE polls (id bigint PRIMARY KEY, multiple boolean)",
          "CREATE TABLE poll_opts (id bigint PRIMARY KEY, poll_id bigint, vote_count integer)",
          "CREATE TABLE quizzes (id bigint PRIMARY KEY)",
          "CREATE TABLE quiz_questions (id bigint PRIMARY KEY, quiz_id bigint)",
          "CREATE TABLE quiz_question_opts (id bigint PRIMARY KEY, quiz_question_id bigint, response_count integer)",
          "CREATE TABLE poll_votes (id bigserial PRIMARY KEY, attendee_identifier varchar, poll_id bigint, poll_opt_id bigint, user_id bigint, inserted_at timestamp NOT NULL, updated_at timestamp NOT NULL)",
          "CREATE TABLE quiz_responses (id bigserial PRIMARY KEY, attendee_identifier varchar, quiz_id bigint, quiz_question_id bigint, quiz_question_opt_id bigint, user_id bigint, inserted_at timestamp NOT NULL, updated_at timestamp NOT NULL)",
          "INSERT INTO users VALUES (1)",
          "INSERT INTO polls VALUES (1, true), (2, false)",
          "INSERT INTO poll_opts VALUES (10, 1, 99), (11, 1, 99), (12, 1, 99), (20, 2, 99), (21, 2, 99)",
          "INSERT INTO quizzes VALUES (1)",
          "INSERT INTO quiz_questions VALUES (1, 1)",
          "INSERT INTO quiz_question_opts VALUES (100, 1, 99), (101, 1, 99), (102, 1, 99)"
        ] do
      Repo.query!(sql)
    end

    :ok
  end

  test "reserves existing voters without changing historical rows or counters" do
    poll_vote("'1'", "NULL", 1, 10, "00")
    poll_vote("'1'", "NULL", 1, 11, "01")
    poll_vote("'1'", "NULL", 1, 10, "02")
    poll_vote("NULL", "1", 2, 20, "00")
    poll_vote("NULL", "1", 2, 21, "02")
    quiz_response("'1'", "NULL", 100, "00")
    quiz_response("'1'", "NULL", 101, "01")
    quiz_response("'1'", "NULL", 100, "02")
    quiz_response("NULL", "1", 101, "00")
    quiz_response("NULL", "1", 100, "02")
    before = history()

    migrate(:up)

    assert history() == before
    assert rows("SELECT count(*) FROM poll_ballots") == [[2]]
    assert rows("SELECT count(*) FROM quiz_question_submissions") == [[2]]
    assert rows("SELECT count(*) FROM poll_votes WHERE poll_ballot_id IS NOT NULL") == [[0]]

    assert rows(
             "SELECT count(*) FROM quiz_responses WHERE quiz_question_submission_id IS NOT NULL"
           ) ==
             [[0]]

    # Both kinds of historical identity are reserved even with duplicate options.
    for identity <- ["NULL, '1'", "1, NULL"] do
      poll_id = if identity == "NULL, '1'", do: 1, else: 2

      assert rows("""
             INSERT INTO poll_ballots (poll_id, user_id, attendee_identifier, inserted_at, updated_at)
             VALUES (#{poll_id}, #{identity}, now(), now()) ON CONFLICT DO NOTHING RETURNING id
             """) == []

      assert rows("""
             INSERT INTO quiz_question_submissions
               (quiz_id, quiz_question_id, user_id, attendee_identifier, inserted_at, updated_at)
             VALUES (1, 1, #{identity}, now(), now()) ON CONFLICT DO NOTHING RETURNING id
             """) == []
    end

    migrate(:down)
    assert history() == before
  end

  test "keeps historical rows without a usable identity instead of deleting them" do
    poll_vote("NULL", "NULL", 1, 10, "00")
    poll_vote("''", "NULL", 1, 11, "00")
    quiz_response("NULL", "NULL", 100, "00")
    quiz_response("''", "NULL", 101, "00")
    before = history()

    migrate(:up)

    assert history() == before
    assert rows("SELECT count(*) FROM poll_ballots") == [[0]]
    assert rows("SELECT count(*) FROM quiz_question_submissions") == [[0]]
  end

  defp history do
    %{
      votes:
        rows(
          "SELECT id, attendee_identifier, user_id, poll_id, poll_opt_id, inserted_at, updated_at FROM poll_votes ORDER BY id"
        ),
      responses:
        rows(
          "SELECT id, attendee_identifier, user_id, quiz_id, quiz_question_id, quiz_question_opt_id, inserted_at, updated_at FROM quiz_responses ORDER BY id"
        ),
      poll_counts: rows("SELECT id, vote_count FROM poll_opts ORDER BY id"),
      quiz_counts: rows("SELECT id, response_count FROM quiz_question_opts ORDER BY id")
    }
  end

  defp migrate(operation) do
    Ecto.Migration.Runner.run(
      Repo,
      Repo.config(),
      20_261_025_160_002,
      Migration,
      :forward,
      operation,
      operation,
      log: false
    )
  end

  defp poll_vote(attendee, user_id, poll_id, option_id, second) do
    Repo.query!("""
    INSERT INTO poll_votes (attendee_identifier, user_id, poll_id, poll_opt_id, inserted_at, updated_at)
    VALUES (#{attendee}, #{user_id}, #{poll_id}, #{option_id},
      '2026-01-01 00:00:#{second}', '2026-01-01 00:00:#{second}')
    """)
  end

  defp quiz_response(attendee, user_id, option_id, second) do
    Repo.query!("""
    INSERT INTO quiz_responses
      (attendee_identifier, user_id, quiz_id, quiz_question_id, quiz_question_opt_id, inserted_at, updated_at)
    VALUES (#{attendee}, #{user_id}, 1, 1, #{option_id},
      '2026-01-01 00:00:#{second}', '2026-01-01 00:00:#{second}')
    """)
  end

  defp rows(sql), do: Repo.query!(sql).rows
end
