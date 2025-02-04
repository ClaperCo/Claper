defmodule Claper.Repo.Migrations.AddStoryVisibleToPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :story_visible, :boolean, default: false
    end
  end
end
