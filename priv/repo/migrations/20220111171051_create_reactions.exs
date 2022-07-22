defmodule Claper.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions) do
      add :icon, :string
      add :attendee_identifier, :string
      add :post_id, references(:posts, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:reactions, [:icon, :post_id, :user_id])
    create unique_index(:reactions, [:icon, :post_id, :attendee_identifier])
  end
end
