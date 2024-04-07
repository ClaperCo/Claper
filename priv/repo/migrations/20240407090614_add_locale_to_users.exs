defmodule Claper.Repo.Migrations.AddTimezoneAndLocaleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :locale, :string
    end
  end
end
