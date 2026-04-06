defmodule Claper.Repo.Migrations.CreatePresenterNotes do
  use Ecto.Migration

  def change do
    create table(:presenter_notes) do
      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all),
        null: false

      add :slide_position, :integer, null: false
      add :content, :text, default: ""

      timestamps()
    end

    create unique_index(:presenter_notes, [:presentation_file_id, :slide_position])
  end
end
