defmodule Claper.Repo.Migrations.AddMultipleFromStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :multiple, :boolean, default: false
    end

    drop index(:story_votes, [:story_id, :user_id]), mode: :cascade
    drop index(:story_votes, [:story_id, :attendee_identifier]), mode: :cascade
  end
end
