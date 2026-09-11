defmodule Claper.Repo.Migrations.AddTypeToPolls do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :type, :string, default: "choice", null: false
    end
  end
end
