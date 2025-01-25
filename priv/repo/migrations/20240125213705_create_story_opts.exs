defmodule Claper.Repo.Migrations.CreateStoryOpts do
  use Ecto.Migration

  def change do
    create table(:story_opts) do
      add :content, :string, null: false
      add :vote_count, :integer, default: 0
      add :story_id, references(:stories, on_delete: :delete_all)

      timestamps()
    end
  end
end
