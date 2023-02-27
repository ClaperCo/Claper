defmodule Claper.Repo.Migrations.CreateFormSubmits do
  use Ecto.Migration

  def change do
    create table(:form_submits) do
      add :attendee_identifier, :string
      add :form_id, references(:forms, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)
      add :response, :map, default: "[]"

      timestamps()
    end

    create index(:form_submits, [:form_id, :user_id])
    create index(:form_submits, [:form_id, :attendee_identifier])
  end
end
