defmodule Claper.Repo.Migrations.AddReplyToPosts do
  use Ecto.Migration

  def change do
    alter table(:posts) do
      add :reply_body, :string
      add :replied_at, :naive_datetime
    end
  end
end
