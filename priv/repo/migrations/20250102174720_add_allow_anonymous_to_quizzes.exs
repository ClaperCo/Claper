defmodule Claper.Repo.Migrations.AddAllowAnonymousToQuizzes do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      add :allow_anonymous, :boolean, default: true
    end
  end
end
