defmodule Claper.Repo.Migrations.AddApprovalToLtiRegistrations do
  use Ecto.Migration

  def up do
    alter table(:lti_13_registrations) do
      add :approved_at, :naive_datetime
      add :approved_by_id, references(:users, on_delete: :nilify_all)
    end

    create index(:lti_13_registrations, [:approved_by_id])

    flush()

    execute(backfill_sql())
  end

  # Only platforms registered by an administrator stay trusted; every other
  # platform must be reviewed by an administrator before it can launch again.
  # Public so the backfill semantics can be exercised by tests.
  def backfill_sql do
    """
    UPDATE lti_13_registrations AS r
    SET approved_at = (NOW() AT TIME ZONE 'UTC')::timestamp(0), approved_by_id = r.user_id
    FROM users AS u
    JOIN roles AS ro ON ro.id = u.role_id
    WHERE u.id = r.user_id AND ro.name = 'admin'
    """
  end

  def down do
    drop index(:lti_13_registrations, [:approved_by_id])

    alter table(:lti_13_registrations) do
      remove :approved_by_id
      remove :approved_at
    end
  end
end
