defmodule Claper.Repo.Migrations.RemoveUniquenessOfHashFromPresentationFiles do
  use Ecto.Migration

  def up do
    drop_if_exists index(:presentation_files, [:hash])
    create unique_index(:presentation_files, [:hash, :event_id])
  end

  def down do
    drop_if_exists index(:presentation_files, [:hash, :event_id])
    create unique_index(:presentation_files, [:hash])
  end
end
