defmodule Claper.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string, null: false
      add :resource_type, :string
      add :resource_id, :bigint
      add :metadata, :map, default: %{}
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false)
    end

    create index(:audit_logs, [:inserted_at])
    create index(:audit_logs, [:action, :inserted_at])
    create index(:audit_logs, [:user_id, :inserted_at])
  end
end
