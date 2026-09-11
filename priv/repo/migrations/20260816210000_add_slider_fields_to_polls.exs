defmodule Claper.Repo.Migrations.AddSliderFieldsToPolls do
  use Ecto.Migration

  def change do
    alter table(:polls) do
      add :min_value, :integer, default: 1, null: false
      add :max_value, :integer, default: 10, null: false
      add :min_label, :string
      add :max_label, :string
    end
  end
end
