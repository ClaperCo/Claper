defmodule Claper.Repo.Migrations.CreateQuizzes do
  use Ecto.Migration

  def change do
    create table(:quizzes) do
      add :title, :string, size: 255
      add :position, :integer, default: 0
      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all)
      add :enabled, :boolean, default: false
      add :show_results, :boolean, default: false

      timestamps()
    end

    create table(:quiz_questions) do
      add :content, :string, size: 255
      add :type, :string, default: "qcm"
      add :quiz_id, references(:quizzes, on_delete: :delete_all)

      timestamps()
    end

    create table(:quiz_question_opts) do
      add :content, :string, size: 255
      add :is_correct, :boolean, default: false
      add :response_count, :integer, default: 0
      add :quiz_question_id, references(:quiz_questions, on_delete: :delete_all)

      timestamps()
    end

    create table(:quiz_responses) do
      add :attendee_identifier, :string
      add :quiz_id, references(:quizzes, on_delete: :delete_all)
      add :quiz_question_id, references(:quiz_questions, on_delete: :delete_all)
      add :quiz_question_opt_id, references(:quiz_question_opts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:quizzes, [:presentation_file_id])
    create index(:quiz_questions, [:quiz_id])
    create index(:quiz_question_opts, [:quiz_question_id])
    create index(:quiz_responses, [:quiz_id])
    create index(:quiz_responses, [:quiz_question_id])
    create index(:quiz_responses, [:quiz_question_opt_id])
    create index(:quiz_responses, [:user_id])
  end
end
