defmodule Claper.Repo.Migrations.AllowReusingDeletedUserEmails do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:users, [:email])

    execute """
    WITH ranked_users AS (
      SELECT
        id,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY inserted_at DESC, id DESC) AS email_position
      FROM users
      WHERE deleted_at IS NULL
    )
    UPDATE users
    SET deleted_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
    FROM ranked_users
    WHERE users.id = ranked_users.id AND ranked_users.email_position > 1
    """

    create unique_index(:users, [:email], where: "deleted_at IS NULL")
  end
end
