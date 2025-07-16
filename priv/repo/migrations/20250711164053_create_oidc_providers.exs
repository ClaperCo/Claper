defmodule Claper.Repo.Migrations.CreateOidcProviders do
  use Ecto.Migration

  def change do
    create table(:oidc_providers) do
      add :name, :string, null: false
      add :issuer, :string, null: false
      add :client_id, :string, null: false
      add :client_secret, :string, null: false
      add :redirect_uri, :string, null: false
      add :response_type, :string, default: "code"
      add :response_mode, :string
      add :scope, :string, default: "openid email profile"
      add :active, :boolean, default: true

      timestamps()
    end

    create index(:oidc_providers, [:name])
    create unique_index(:oidc_providers, [:issuer])
  end
end
