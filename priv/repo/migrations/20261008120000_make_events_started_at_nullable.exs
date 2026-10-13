defmodule Claper.Repo.Migrations.MakeEventsStartedAtNullable do
  use Ecto.Migration

  # A NULL `started_at` means the event is unscheduled. Rolling back fails if
  # unscheduled events exist.
  def change do
    alter table(:events) do
      modify :started_at, :naive_datetime, null: true, from: {:naive_datetime, null: false}
    end
  end
end
