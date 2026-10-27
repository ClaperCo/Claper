defmodule Claper.Repo.Migrations.SecureLtiIdentityBindings do
  use Ecto.Migration

  def change do
    alter table(:lti_13_users) do
      # Do not backfill: old email-only links cannot establish local account ownership.
      add :provisioned_at, :naive_datetime
      add :authorized_at, :naive_datetime
    end

    create table(:lti_13_launch_states) do
      add :state, :string, null: false
      add :nonce, :string, null: false
      add :registration_id, references(:lti_13_registrations, on_delete: :delete_all), null: false
      timestamps(updated_at: false)
    end

    create unique_index(:lti_13_launch_states, [:state])
    create index(:lti_13_launch_states, [:inserted_at])
  end
end
