defmodule Claper.Repo.Migrations.RemoveIsAdminFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :is_admin
    end
  end
end
