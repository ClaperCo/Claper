defmodule Claper.Repo.Migrations.AddShowPollResultsEnabledToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :show_poll_results_enabled, :boolean, default: true
    end
  end
end
