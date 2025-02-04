defmodule Claper.Repo.Migrations.AddNextSlideToStoryOpts do
  use Ecto.Migration

  def change do
    alter table(:story_opts) do
      add :next_slide, :integer, default: 1
    end
  end
end
