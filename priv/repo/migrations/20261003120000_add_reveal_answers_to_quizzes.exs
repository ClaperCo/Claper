defmodule Claper.Repo.Migrations.AddRevealAnswersToQuizzes do
  use Ecto.Migration

  def up do
    alter table(:quizzes) do
      add :reveal_answers, :boolean, default: false
    end

    flush()

    # A quiz that shows its results keeps showing the correct answers too.
    execute "UPDATE quizzes SET reveal_answers = true WHERE show_results"
  end

  def down do
    alter table(:quizzes) do
      remove :reveal_answers
    end
  end
end
