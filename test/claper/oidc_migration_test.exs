defmodule Claper.OidcMigrationTest do
  use Claper.DataCase

  unless Code.ensure_loaded?(Claper.Repo.Migrations.ScopeOidcSubjectsToIssuers) do
    Code.require_file(
      Path.expand(
        "../../priv/repo/migrations/20261026150000_scope_oidc_subjects_to_issuers.exs",
        __DIR__
      )
    )
  end

  alias Claper.Repo.Migrations.ScopeOidcSubjectsToIssuers, as: Migration

  setup do
    schema = "oidc_migration_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE SCHEMA #{schema}")
    Repo.query!("SET LOCAL search_path TO #{schema}")

    Repo.query!("""
    CREATE TABLE oidc_users (
      id bigint PRIMARY KEY,
      issuer varchar NOT NULL,
      sub varchar NOT NULL,
      user_id bigint NOT NULL
    )
    """)

    Repo.query!("""
    INSERT INTO oidc_users VALUES (1, 'https://issuer.example.com', 'subject', 10)
    """)

    :ok
  end

  test "a fresh migration enforces issuer-scoped identity uniqueness" do
    migrate_up()

    assert Repo.query!("""
           INSERT INTO oidc_users VALUES (2, 'https://issuer.example.com', 'subject', 20)
           ON CONFLICT DO NOTHING RETURNING user_id
           """).rows == []

    assert Repo.query!("""
           INSERT INTO oidc_users VALUES (3, 'https://other.example.com', 'subject', 20)
           RETURNING user_id
           """).rows == [[20]]

    assert Repo.query!("SELECT id, user_id FROM oidc_users ORDER BY id").rows == [
             [1, 10],
             [3, 20]
           ]
  end

  test "a pre-existing identity index is preserved when the migration is retried" do
    Repo.query!("""
    CREATE UNIQUE INDEX oidc_users_issuer_sub_index ON oidc_users (issuer, sub)
    """)

    index_before = index_oid()
    migrate_up()
    migrate_up()

    assert index_oid() == index_before
    assert Repo.query!("SELECT id, user_id FROM oidc_users").rows == [[1, 10]]

    assert Repo.query!("""
           INSERT INTO oidc_users VALUES (2, 'https://issuer.example.com', 'subject', 20)
           ON CONFLICT DO NOTHING RETURNING user_id
           """).rows == []
  end

  defp index_oid do
    [[oid]] = Repo.query!("SELECT to_regclass('oidc_users_issuer_sub_index')::oid").rows
    oid
  end

  defp migrate_up do
    Ecto.Migration.Runner.run(
      Repo,
      Repo.config(),
      20_261_026_150_000,
      Migration,
      :forward,
      :up,
      :up,
      log: false
    )
  end
end
