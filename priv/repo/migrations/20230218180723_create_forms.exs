defmodule Claper.Repo.Migrations.CreateForms do
  use Ecto.Migration

  def change do
    create table(:forms) do
      add :title, :string, null: false
      add :position, :integer, default: 0
      add :enabled, :boolean, default: true
      add :presentation_file_id, references(:presentation_files, on_delete: :nothing)
      add :fields, :map, default: "[]"

      timestamps()
    end
  end
end
