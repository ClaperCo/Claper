defmodule Claper.Repo.Migrations.AddProviderToEmbeds do
  use Ecto.Migration

  def change do
    alter table(:embeds) do
      add :provider, :string, default: "custom"
    end
  end
end
