defmodule Claper.Repo.Migrations.CreatePostReplies do
  use Ecto.Migration

  def up do
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

    execute("""
    INSERT INTO post_replies (
      uuid,
      body,
      author_role,
      post_id,
      user_id,
      inserted_at,
      updated_at
    )
    SELECT
      gen_random_uuid(),
      posts.reply_body,
      'host',
      posts.id,
      events.user_id,
      COALESCE(posts.replied_at, posts.updated_at, NOW()),
      COALESCE(posts.replied_at, posts.updated_at, NOW())
    FROM posts
    INNER JOIN events ON events.id = posts.event_id
    WHERE posts.reply_body IS NOT NULL
    """)

    alter table(:posts) do
      remove :reply_body
      remove :replied_at
    end
  end

  def down do
    alter table(:posts) do
      add :reply_body, :string
      add :replied_at, :naive_datetime
    end

    execute("""
    UPDATE posts
    SET
      reply_body = latest_reply.body,
      replied_at = latest_reply.inserted_at
    FROM (
      SELECT DISTINCT ON (post_id)
        post_id,
        body,
        inserted_at
      FROM post_replies
      ORDER BY post_id, id DESC
    ) AS latest_reply
    WHERE posts.id = latest_reply.post_id
    """)

    drop table(:post_replies)
  end
end
