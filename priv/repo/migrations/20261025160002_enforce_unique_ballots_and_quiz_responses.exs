defmodule Claper.Repo.Migrations.EnforceUniqueBallotsAndQuizResponses do
  use Ecto.Migration

  def up do
    create table(:poll_ballots) do
      add :poll_id, references(:polls, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :attendee_identifier, :string
      timestamps()
    end

    create unique_index(:poll_ballots, [:poll_id, :user_id], where: "user_id IS NOT NULL")

    create unique_index(:poll_ballots, [:poll_id, :attendee_identifier],
             where: "attendee_identifier IS NOT NULL"
           )

    create constraint(:poll_ballots, :poll_ballots_one_identity,
             check:
               "num_nonnulls(user_id, attendee_identifier) = 1 AND (attendee_identifier IS NULL OR attendee_identifier <> '')"
           )

    create table(:quiz_question_submissions) do
      add :quiz_id, references(:quizzes, on_delete: :delete_all), null: false
      add :quiz_question_id, references(:quiz_questions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :attendee_identifier, :string
      timestamps()
    end

    create unique_index(:quiz_question_submissions, [:quiz_question_id, :user_id],
             where: "user_id IS NOT NULL",
             name: :quiz_submissions_question_user_index
           )

    create unique_index(:quiz_question_submissions, [:quiz_question_id, :attendee_identifier],
             where: "attendee_identifier IS NOT NULL",
             name: :quiz_submissions_question_attendee_index
           )

    create constraint(:quiz_question_submissions, :quiz_submissions_one_identity,
             check:
               "num_nonnulls(user_id, attendee_identifier) = 1 AND (attendee_identifier IS NULL OR attendee_identifier <> '')"
           )

    # Historical rows keep NULL links; new submissions provide their parent ID.
    alter table(:poll_votes) do
      add :poll_ballot_id, references(:poll_ballots, on_delete: :delete_all)
    end

    alter table(:quiz_responses) do
      add :quiz_question_submission_id,
          references(:quiz_question_submissions, on_delete: :delete_all)
    end

    create unique_index(:poll_votes, [:poll_ballot_id, :poll_opt_id])

    create unique_index(:quiz_responses, [:quiz_question_submission_id, :quiz_question_opt_id],
             name: :quiz_responses_submission_option_index
           )

    # Reserve existing participants without editing their votes or counters.
    # Rows with no usable identity remain untouched and cannot identify a voter.
    execute("""
    INSERT INTO poll_ballots (poll_id, user_id, attendee_identifier, inserted_at, updated_at)
    SELECT poll_id, user_id, attendee_identifier, min(inserted_at), min(inserted_at)
    FROM poll_votes
    WHERE poll_id IS NOT NULL AND num_nonnulls(user_id, attendee_identifier) = 1
      AND (attendee_identifier IS NULL OR attendee_identifier <> '')
    GROUP BY poll_id, user_id, attendee_identifier
    """)

    execute("""
    INSERT INTO quiz_question_submissions
      (quiz_id, quiz_question_id, user_id, attendee_identifier, inserted_at, updated_at)
    SELECT quiz_id, quiz_question_id, user_id, attendee_identifier, min(inserted_at), min(inserted_at)
    FROM quiz_responses
    WHERE quiz_id IS NOT NULL AND quiz_question_id IS NOT NULL
      AND num_nonnulls(user_id, attendee_identifier) = 1
      AND (attendee_identifier IS NULL OR attendee_identifier <> '')
    GROUP BY quiz_id, quiz_question_id, user_id, attendee_identifier
    """)
  end

  def down do
    alter table(:poll_votes) do
      remove :poll_ballot_id
    end

    alter table(:quiz_responses) do
      remove :quiz_question_submission_id
    end

    drop table(:poll_ballots)
    drop table(:quiz_question_submissions)
  end
end
