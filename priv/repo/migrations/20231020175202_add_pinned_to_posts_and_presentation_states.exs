defmodule Claper.Repo.Migrations.AddPinnedToPostsAndPresentationStates do
  use Ecto.Migration

  def change do
    alter table(:presentation_states) do
      add :show_only_pinned, :boolean, default: false
    end

    alter table(:posts) do
      add :pinned, :boolean, default: false
    end
  end
end
