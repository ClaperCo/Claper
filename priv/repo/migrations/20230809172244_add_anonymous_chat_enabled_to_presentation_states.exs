defmodule Claper.Repo.Migrations.AddAnonymousChatEnabledToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :anonymous_chat_enabled, :boolean, default: true
    end
  end
end
