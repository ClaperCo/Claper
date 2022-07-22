defmodule Claper.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :body, :string, null: false
      add :like_count, :integer, default: 0
      add :love_count, :integer, default: 0
      add :lol_count, :integer, default: 0
      add :position, :integer, default: 0
      add :name, :string
      add :attendee_identifier, :string
      add :event_id, references(:events, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:posts, [:uuid])
    create unique_index(:posts, [:id])
    create index(:posts, [:attendee_identifier])
    create index(:posts, [:user_id])
  end
end
