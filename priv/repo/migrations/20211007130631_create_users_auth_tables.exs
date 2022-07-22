defmodule Claper.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto", ""

    create table(:users) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :is_admin, :boolean, null: false, default: false, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email])
    create index(:users, [:uuid])

    create table(:users_tokens) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, on_delete: :delete_all)
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create index(:users_tokens, [:uuid])
    create unique_index(:users_tokens, [:context, :token])
  end
end
