defmodule Claper.Repo.Migrations.ScopeOidcSubjectsToIssuers do
  use Ecto.Migration

  def up do
    # Concurrent first logins could previously insert duplicate bindings for the
    # same issuer and subject. Keep the oldest binding before enforcing uniqueness.
    execute """
    DELETE FROM oidc_users a
    USING oidc_users b
    WHERE a.issuer = b.issuer AND a.sub = b.sub AND a.id > b.id
    """

    create_if_not_exists unique_index(:oidc_users, [:issuer, :sub])
  end

  def down do
    drop unique_index(:oidc_users, [:issuer, :sub])
  end
end
