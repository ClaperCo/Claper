defmodule Claper.Repo.Migrations.AddLtiTables do
  use Ecto.Migration

  def change do
    create table(:lti_13_jwks) do
      add :pem, :text
      add :typ, :string
      add :alg, :string
      add :kid, :string
      add :active, :boolean, default: false, null: false

      timestamps()
    end

    create table(:lti_13_registrations) do
      add :issuer, :string
      add :client_id, :string
      add :key_set_url, :string
      add :auth_token_url, :string
      add :auth_login_url, :string
      add :auth_server, :string

      add :tool_jwk_id, references(:lti_13_jwks)

      timestamps()
    end

    create unique_index(:lti_13_registrations, :client_id)

    create table(:lti_13_users) do
      add :sub, :string, null: false
      add :name, :string
      add :email, :string, null: false
      add :roles, {:array, :string}, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      add :registration_id, references(:lti_13_registrations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:lti_13_users, :sub)

    create table(:lti_13_nonces) do
      add :value, :string
      add :domain, :string
      add :lti_user_id, references(:lti_13_users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:lti_13_nonces, [:value, :domain], name: :value_domain_index)

    create table(:lti_13_deployments) do
      add :deployment_id, :integer

      add :registration_id, references(:lti_13_registrations, on_delete: :delete_all), null: false

      timestamps()
    end

    create table(:lti_13_resources) do
      add :title, :string
      add :resource_id, :integer
      add :event_id, references(:events, on_delete: :delete_all), null: false

      add :registration_id, references(:lti_13_registrations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:lti_13_resources, [:resource_id, :registration_id])
  end
end
