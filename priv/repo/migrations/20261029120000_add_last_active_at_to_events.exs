defmodule Claper.Repo.Migrations.AddLastActiveAtToEvents do
  use Ecto.Migration

  def up do
    alter table(:events) do
      add :last_active_at, :naive_datetime
    end

    # Visits were never recorded, so the latest slide change or message of each
    # running event stands in for them. Otherwise events presented every week but
    # not edited for a while would look abandoned to the first inactivity cleanup.
    execute """
    UPDATE events AS e
    SET last_active_at = s.updated_at
    FROM (
      SELECT pf.event_id, MAX(ps.updated_at) AS updated_at
      FROM presentation_files AS pf
      JOIN presentation_states AS ps ON ps.presentation_file_id = pf.id
      GROUP BY pf.event_id
    ) AS s
    WHERE s.event_id = e.id AND e.expired_at IS NULL
    """

    execute """
    UPDATE events AS e
    SET last_active_at = GREATEST(e.last_active_at, p.updated_at)
    FROM (
      SELECT event_id, MAX(updated_at) AS updated_at
      FROM posts
      GROUP BY event_id
    ) AS p
    WHERE p.event_id = e.id AND e.expired_at IS NULL
    """
  end

  def down do
    alter table(:events) do
      remove :last_active_at
    end
  end
end
