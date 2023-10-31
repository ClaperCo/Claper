defmodule Claper.Repo.Migrations.CreateEmbeds do
  use Ecto.Migration

  def change do
    create table(:embeds) do
      add :title, :string, null: false
      add :content, :text, null: false
      add :position, :integer, default: 0
      add :enabled, :boolean, default: true
      add :presentation_file_id, references(:presentation_files, on_delete: :nilify_all)

      timestamps()
    end
  end
end
