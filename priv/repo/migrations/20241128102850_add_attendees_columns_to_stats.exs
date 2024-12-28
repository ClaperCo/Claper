defmodule Claper.Repo.Migrations.AddAttendeesColumnsToStats do
  use Ecto.Migration

  def up do
    alter table(:stats) do
      add :attendee_identifier, :string
      add :user_id, references(:users, on_delete: :delete_all)
      remove :status
    end

    create unique_index(:stats, [:event_id, :user_id])
    create unique_index(:stats, [:event_id, :attendee_identifier])
  end

  def down do
    drop unique_index(:stats, [:event_id, :attendee_identifier])
    drop unique_index(:stats, [:event_id, :user_id])

    alter table(:stats) do
      remove :attendee_identifier
      remove :user_id
      add :status, :string
    end
  end
end
