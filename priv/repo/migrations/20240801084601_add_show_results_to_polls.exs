defmodule Claper.Repo.Migrations.AddShowResultsToPolls do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :show_results, :boolean, default: true
    end
  end
end
