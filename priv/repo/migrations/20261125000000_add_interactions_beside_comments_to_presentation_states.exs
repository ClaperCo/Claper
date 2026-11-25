defmodule Claper.Repo.Migrations.AddInteractionsBesideCommentsToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :interactions_beside_comments, :boolean, default: true
    end
  end
end
