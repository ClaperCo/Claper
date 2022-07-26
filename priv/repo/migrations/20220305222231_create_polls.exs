defmodule Claper.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    create table(:polls) do
      add :title, :string, null: false
      add :position, :integer, default: 0
      add :presentation_file_id, references(:presentation_files, on_delete: :nilify_all)
      add :enabled, :boolean, default: true

      timestamps()
    end
  end
end
