defmodule Claper.Repo.Migrations.AddAuthenticatedChatOnlyToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :authenticated_chat_only, :boolean, default: false
    end
  end
end
