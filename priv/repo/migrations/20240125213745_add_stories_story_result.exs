defmodule Claper.Repo.Migrations.AddStoryResultToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :story_result, :integer, default: -1
    end
  end
end
