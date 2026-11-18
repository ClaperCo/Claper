defmodule Claper.Repo.Migrations.CreateScales do
  use Ecto.Migration

  def change do
    create table(:scales) do
      add :title, :string, size: 255, null: false
      add :min_value, :integer, default: 1, null: false
      add :max_value, :integer, default: 10, null: false
      add :step, :integer, default: 1, null: false
      add :min_label, :string
      add :max_label, :string
      add :position, :integer, default: 0
      add :enabled, :boolean, default: false
      add :show_results, :boolean, default: true
      add :presentation_file_id, references(:presentation_files, on_delete: :delete_all)

      timestamps()
    end

    create constraint(:scales, :min_below_max, check: "min_value < max_value")
    create constraint(:scales, :step_positive, check: "step > 0")
    create index(:scales, [:presentation_file_id])

    create table(:scale_responses) do
      add :value, :integer, null: false
      add :attendee_identifier, :string
      add :scale_id, references(:scales, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create constraint(:scale_responses, :one_respondent,
             check: "(user_id IS NULL) <> (attendee_identifier IS NULL)"
           )

    create index(:scale_responses, [:scale_id, :value])
    create index(:scale_responses, [:user_id])

    create unique_index(:scale_responses, [:scale_id, :attendee_identifier],
             where: "attendee_identifier IS NOT NULL",
             name: :scale_responses_attendee_index
           )

    create unique_index(:scale_responses, [:scale_id, :user_id],
             where: "user_id IS NOT NULL",
             name: :scale_responses_user_index
           )
  end
end
