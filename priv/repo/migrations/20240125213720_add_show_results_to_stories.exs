defmodule Claper.Repo.Migrations.AddShowResultsToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :show_results, :boolean, default: true
    end
  end
end
