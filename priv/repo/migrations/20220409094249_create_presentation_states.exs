defmodule Claper.Repo.Migrations.CreatePresentationStates do
  use Ecto.Migration

  def change do
    create table(:presentation_states) do
      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all)
      add :position, :integer, default: 0
      add :chat_visible, :boolean, default: false
      add :poll_visible, :boolean, default: false
      add :join_screen_visible, :boolean, default: false
      add :banned, {:array, :string}, default: []

      timestamps()
    end
  end
end
