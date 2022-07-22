defmodule Claper.Repo.Migrations.PresentationFilesAddAudiencePeakColumn do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :audience_peak, :integer, default: 1
    end
  end
end
