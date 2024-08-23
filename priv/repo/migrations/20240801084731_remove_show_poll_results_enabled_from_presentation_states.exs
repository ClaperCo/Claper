defmodule Claper.Repo.Migrations.RemoveShowPollResultsEnabledFromPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      remove :show_poll_results_enabled
    end
  end
end
