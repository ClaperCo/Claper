defmodule Claper.Repo.Migrations.AddResultToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :result, :integer, default: -1
    end
  end
end
