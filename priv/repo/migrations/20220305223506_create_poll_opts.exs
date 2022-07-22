defmodule Claper.Repo.Migrations.CreatePollOpts do
  use Ecto.Migration

  def change do
    create table(:poll_opts) do
      add :content, :string, null: false
      add :vote_count, :integer, default: 0
      add :poll_id, references(:polls, on_delete: :delete_all)

      timestamps()
    end
  end
end
