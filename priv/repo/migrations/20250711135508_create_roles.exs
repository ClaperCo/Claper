defmodule Claper.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :permissions, :map, default: %{}

      timestamps()
    end

    create unique_index(:roles, [:name])
  end
end
