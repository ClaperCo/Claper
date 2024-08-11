defmodule Claper.Repo.Migrations.AddOidcUsers do
  use Ecto.Migration

  def change do
    create table(:oidc_users) do
      add :sub, :string, null: false
      add :name, :string
      add :email, :string
      add :issuer, :string, null: false
      add :provider, :string, null: false
      add :id_token, :text
      add :refresh_token, :text
      add :access_token, :text
      add :expires_at, :naive_datetime
      add :photo_url, :string
      add :groups, {:array, :string}
      add :roles, :string
      add :organization, :string
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end
  end
end
