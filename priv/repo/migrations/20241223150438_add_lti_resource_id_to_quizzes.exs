defmodule Claper.Repo.Migrations.AddLtiResourceIdToQuizzes do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      add :lti_resource_id, references(:lti_13_resources, on_delete: :delete_all)
    end
  end
end
