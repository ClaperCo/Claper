defmodule Claper.Repo.Migrations.CreateStoryVotes do
  use Ecto.Migration

  def change do
    create table(:story_votes) do
      add :attendee_identifier, :string
      add :story_id, references(:stories, on_delete: :delete_all)
      add :story_opt_id, references(:story_opts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:story_votes, [:story_id, :user_id])
    create unique_index(:story_votes, [:story_id, :attendee_identifier])
  end
end
