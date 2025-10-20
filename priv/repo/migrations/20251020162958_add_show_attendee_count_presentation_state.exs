defmodule Claper.Repo.Migrations.AddShowAttendeeCountPresentationState do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :show_attendee_count, :boolean, default: true
    end
  end
end
