defmodule Claper.Repo.Migrations.AddSlugToOidcProviders do
  use Ecto.Migration

  def up do
    alter table(:oidc_providers) do
      add :slug, :string
      add :position, :integer, default: 0
    end

    # Backfill a URL-safe identifier from the display name. The login routes
    # address a provider by slug, so it has to exist for rows created before
    # this migration.
    execute("""
    UPDATE oidc_providers
    SET slug = regexp_replace(
      regexp_replace(lower(name), '[^a-z0-9]+', '-', 'g'),
      '^-+|-+$',
      '',
      'g'
    )
    WHERE slug IS NULL
    """)

    # Two providers may share a display name, so suffix the later rows with
    # their id instead of failing on the unique index.
    execute("""
    UPDATE oidc_providers p
    SET slug = p.slug || '-' || p.id
    WHERE EXISTS (
      SELECT 1 FROM oidc_providers other
      WHERE other.slug = p.slug AND other.id < p.id
    )
    """)

    execute("ALTER TABLE oidc_providers ALTER COLUMN slug SET NOT NULL")

    # oidc_users declared unique_constraint(:sub) but no index backed it, so
    # duplicates were possible. The real key is (issuer, sub): two providers may
    # legitimately mint the same sub value.
    execute("""
    DELETE FROM oidc_users a
    USING oidc_users b
    WHERE a.issuer = b.issuer AND a.sub = b.sub AND a.id < b.id
    """)

    create unique_index(:oidc_users, [:issuer, :sub])
    create unique_index(:oidc_providers, [:slug])
  end

  def down do
    drop unique_index(:oidc_providers, [:slug])
    drop unique_index(:oidc_users, [:issuer, :sub])

    alter table(:oidc_providers) do
      remove :position
      remove :slug
    end
  end
end
