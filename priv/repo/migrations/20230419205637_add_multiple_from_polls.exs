defmodule Claper.Repo.Migrations.AddMultipleFromPolls do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :multiple, :boolean, default: false
    end

    drop index(:poll_votes, [:poll_id, :user_id]), mode: :cascade
    drop index(:poll_votes, [:poll_id, :attendee_identifier]), mode: :cascade
  end
end
