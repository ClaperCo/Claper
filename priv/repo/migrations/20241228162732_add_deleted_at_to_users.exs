defmodule Claper.Repo.Migrations.AddDeletedAtToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :deleted_at, :naive_datetime, null: true
    end

    create index(:users, [:deleted_at])
  end
end
