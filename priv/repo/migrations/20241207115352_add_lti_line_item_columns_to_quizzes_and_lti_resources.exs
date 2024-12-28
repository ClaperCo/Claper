defmodule Claper.Repo.Migrations.AddLtiLineItemColumnsToQuizzesAndEvents do
  use Ecto.Migration

  def change do
    alter table(:quizzes) do
      add :lti_line_item_url, :string
    end

    alter table(:lti_13_resources) do
      add :line_items_url, :string
    end
  end
end
