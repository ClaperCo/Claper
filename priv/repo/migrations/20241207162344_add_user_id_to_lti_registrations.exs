defmodule Claper.Repo.Migrations.AddUserIdToLtiRegistrations do
  use Ecto.Migration

  def change do
    alter table(:lti_13_registrations) do
      add :user_id, references(:users, on_delete: :delete_all)
    end
  end
end
