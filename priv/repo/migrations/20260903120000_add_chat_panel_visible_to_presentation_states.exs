defmodule Claper.Repo.Migrations.AddChatPanelVisibleToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :chat_panel_visible, :boolean, default: true
    end
  end
end
