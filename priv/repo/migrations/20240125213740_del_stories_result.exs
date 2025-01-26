defmodule Claper.Repo.Migrations.DelResultFromStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      remove :result
    end
  end
end
