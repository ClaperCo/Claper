defmodule Claper.Repo.Migrations.CreatePollVotes do
  use Ecto.Migration

  def change do
    create table(:poll_votes) do
      add :attendee_identifier, :string
      add :poll_id, references(:polls, on_delete: :delete_all)
      add :poll_opt_id, references(:poll_opts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:poll_votes, [:poll_id, :user_id])
    create unique_index(:poll_votes, [:poll_id, :attendee_identifier])
  end
end
