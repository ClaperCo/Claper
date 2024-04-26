defmodule Claper.Repo.Migrations.AddMessageReactionEnabledToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :message_reaction_enabled, :boolean, default: true
    end
  end
end
