defmodule Claper.Repo.Migrations.AddOidcIdentityConfirmation do
  use Ecto.Migration

  def up do
    alter table(:oidc_users) do
      add :verified_at, :naive_datetime
    end

    create table(:oidc_pending_identities) do
      add :token_hash, :binary, null: false
      add :browser_hash, :binary, null: false
      add :email, :string, null: false
      add :issuer, :string, null: false
      add :sub, :string, null: false
      add :attrs, :map, null: false

      timestamps(updated_at: false)
    end

    create unique_index(:oidc_pending_identities, [:token_hash])
    create index(:oidc_pending_identities, [:issuer, :sub])

    # Existing bindings may come from email-only linking. One that created its own
    # account cannot have taken over another, so those users keep signing in
    # unchanged; bindings attached to an older account are confirmed once by email.
    execute """
    UPDATE oidc_users AS o
    SET verified_at = o.inserted_at
    FROM users AS u
    WHERE o.user_id = u.id
      AND o.inserted_at BETWEEN u.inserted_at AND u.inserted_at + interval '1 minute'
    """
  end

  def down do
    drop table(:oidc_pending_identities)

    alter table(:oidc_users) do
      remove :verified_at
    end
  end
end
