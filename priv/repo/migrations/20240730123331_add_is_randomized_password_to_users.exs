defmodule Claper.Repo.Migrations.AddIsRandomizedPasswordToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_randomized_password, :boolean, default: false
    end
  end
end
