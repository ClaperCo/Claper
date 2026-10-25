defmodule Claper.Repo.Migrations.CreateWordClouds do
  use Ecto.Migration

  def change do
    create table(:word_clouds) do
      add :title, :string, size: 255, null: false
      add :position, :integer, default: 0
      add :enabled, :boolean, default: false
      add :show_results, :boolean, default: true
      add :max_entries, :integer, default: 1, null: false
      add :hidden_words, {:array, :string}, default: [], null: false
      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all)

      timestamps()
    end

    create table(:word_cloud_entries) do
      add :content, :string, null: false
      add :normalized_content, :string, null: false
      add :attendee_identifier, :string
      add :word_cloud_id, references(:word_clouds, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:word_clouds, [:presentation_file_id])
    create index(:word_cloud_entries, [:word_cloud_id, :normalized_content])
    create index(:word_cloud_entries, [:user_id])

    create unique_index(
             :word_cloud_entries,
             [:word_cloud_id, :attendee_identifier, :normalized_content],
             where: "attendee_identifier IS NOT NULL",
             name: :word_cloud_entries_attendee_word_index
           )

    create unique_index(:word_cloud_entries, [:word_cloud_id, :user_id, :normalized_content],
             where: "user_id IS NOT NULL",
             name: :word_cloud_entries_user_word_index
           )
  end
end
