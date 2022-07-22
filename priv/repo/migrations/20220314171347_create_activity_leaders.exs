defmodule Claper.Repo.Migrations.CreateActivityLeaders do
  use Ecto.Migration

  def change do
    create table(:activity_leaders) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :email, :string, null: false

      timestamps()
    end

    create unique_index(:activity_leaders, [:event_id, :email])
  end
end
