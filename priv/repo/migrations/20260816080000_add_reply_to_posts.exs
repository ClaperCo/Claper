defmodule Claper.Repo.Migrations.CreatePostReplies do
  use Ecto.Migration

  def change do
    create table(:post_replies) do
      add :uuid, :binary_id, null: false, default: fragment("gen_random_uuid()")
      add :body, :string, null: false
      add :author_role, :string, null: false
      add :author_name, :string
      add :attendee_identifier, :string
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:post_replies, [:uuid])
    create index(:post_replies, [:post_id])
    create index(:post_replies, [:user_id])
    create index(:post_replies, [:attendee_identifier])

    create constraint(:post_replies, :valid_author_role,
             check: "author_role IN ('host', 'attendee')"
           )

    create constraint(:post_replies, :one_reply_author,
             check: "num_nonnulls(user_id, attendee_identifier) = 1"
           )
  end
end
