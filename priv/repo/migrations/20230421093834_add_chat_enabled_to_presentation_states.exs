defmodule Claper.Repo.Migrations.AddChatEnabledToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :chat_enabled, :boolean, default: true
    end
  end
end
