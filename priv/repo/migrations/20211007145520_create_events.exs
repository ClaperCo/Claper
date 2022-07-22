defmodule Claper.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :name, :string
      add :code, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :started_at, :naive_datetime, null: false
      add :expired_at, :naive_datetime
      timestamps()
    end

    create unique_index(:events, [:id])
    create unique_index(:events, [:uuid])
    create index(:events, [:user_id])
  end
end
