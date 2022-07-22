defmodule Claper.Repo.Migrations.CreatePresentationFiles do
  use Ecto.Migration

  def change do
    create table(:presentation_files) do
      add :hash, :string
      add :length, :integer
      add :status, :string, default: "processing"
      add :event_id, references(:events, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:presentation_files, [:hash])
  end
end
