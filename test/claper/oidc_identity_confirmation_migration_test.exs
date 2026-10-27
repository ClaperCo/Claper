defmodule Claper.OidcIdentityConfirmationMigrationTest do
  use Claper.DataCase

  unless Code.ensure_loaded?(Claper.Repo.Migrations.AddOidcIdentityConfirmation) do
    Code.require_file(
      Path.expand(
        "../../priv/repo/migrations/20261026160000_add_oidc_identity_confirmation.exs",
        __DIR__
      )
    )
  end

  alias Claper.Repo.Migrations.AddOidcIdentityConfirmation, as: Migration

  setup do
    schema = "oidc_confirmation_migration_#{System.unique_integer([:positive])}"
    Repo.query!("CREATE SCHEMA #{schema}")
    Repo.query!("SET LOCAL search_path TO #{schema}")
    Repo.query!("CREATE TABLE users (id bigint PRIMARY KEY, inserted_at timestamp NOT NULL)")

    Repo.query!("""
    CREATE TABLE oidc_users (id bigint PRIMARY KEY, user_id bigint NOT NULL, inserted_at timestamp NOT NULL)
    """)

    :ok
  end

  test "keeps accounts created by OIDC signing in and re-confirms links to older accounts" do
    Repo.query!("INSERT INTO users VALUES (1, '2026-01-01 10:00:00'), (2, '2025-06-01 09:00:00')")

    Repo.query!("""
    INSERT INTO oidc_users VALUES (10, 1, '2026-01-01 10:00:01'), (20, 2, '2026-01-05 12:00:00')
    """)

    migrate(:up)

    assert Repo.query!("SELECT id, verified_at FROM oidc_users ORDER BY id").rows == [
             # Created its own account: trusted from when it was created.
             [10, ~N[2026-01-01 10:00:01]],
             # Attached to an account that existed months earlier: confirmed once.
             [20, nil]
           ]

    migrate(:down)
    assert Repo.query!("SELECT id FROM oidc_users ORDER BY id").rows == [[10], [20]]
  end

  defp migrate(direction) do
    Ecto.Migration.Runner.run(
      Repo,
      Repo.config(),
      20_261_026_160_000,
      Migration,
      :forward,
      direction,
      direction,
      log: false
    )
  end
end
