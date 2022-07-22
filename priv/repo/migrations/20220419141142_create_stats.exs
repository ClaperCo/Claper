defmodule Claper.Repo.Migrations.CreateStats do
  use Ecto.Migration

  def change do
    create table(:stats) do
      add :event_id, references(:events, on_delete: :delete_all)
      add :status, :string

      timestamps()
    end
  end
end
