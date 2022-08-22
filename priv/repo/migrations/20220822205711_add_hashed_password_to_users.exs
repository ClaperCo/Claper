defmodule Claper.Repo.Migrations.AddHashedPasswordToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :hashed_password, :string, null: false
    end
  end
end
