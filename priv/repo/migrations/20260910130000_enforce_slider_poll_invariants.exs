defmodule Claper.Repo.Migrations.EnforceSliderPollInvariants do
  use Ecto.Migration

  @moduledoc """
  A slider poll keeps one poll_opt per rating value of its range. So far that
  was a convention two concurrent ratings could break, because nothing in the
  database enforced it. This keys those rows by the value they stand for and
  makes the pair unique, so `Claper.Polls.submit_rating/4` can count a rating
  with a single upsert.

  A poll's range gets a check constraint as well: it was only validated for
  slider polls, so a poll could be persisted with a range no rating can satisfy.
  """

  def change do
    alter table(:poll_opts) do
      add :rating_value, :integer
    end

    execute(&merge_duplicate_rating_opts/0, fn -> :ok end)

    create unique_index(:poll_opts, [:poll_id, :rating_value])

    execute(&repair_impossible_ranges/0, fn -> :ok end)

    create constraint(:polls, :polls_value_range,
             check: "min_value >= 0 and max_value <= 100 and min_value < max_value"
           )
  end

  # Ratings recorded before the unique index existed can hold several rows for
  # the same value: move their votes onto the oldest row, add up what they
  # counted, drop the rest, then key every remaining bucket by its value.
  defp merge_duplicate_rating_opts do
    repo().query!("""
    UPDATE poll_votes v
    SET poll_opt_id = keep.id
    FROM poll_opts o
    JOIN (
      SELECT min(o2.id) AS id, o2.poll_id, o2.content
      FROM poll_opts o2
      JOIN polls p ON p.id = o2.poll_id
      WHERE p.type = 'slider' AND o2.content ~ '^[0-9]+$'
      GROUP BY o2.poll_id, o2.content
    ) keep ON keep.poll_id = o.poll_id AND keep.content = o.content
    WHERE v.poll_opt_id = o.id AND o.id <> keep.id
    """)

    repo().query!("""
    UPDATE poll_opts o
    SET vote_count = totals.vote_count
    FROM (
      SELECT min(o2.id) AS id, sum(o2.vote_count) AS vote_count
      FROM poll_opts o2
      JOIN polls p ON p.id = o2.poll_id
      WHERE p.type = 'slider' AND o2.content ~ '^[0-9]+$'
      GROUP BY o2.poll_id, o2.content
    ) totals
    WHERE o.id = totals.id
    """)

    repo().query!("""
    DELETE FROM poll_opts o
    USING polls p
    WHERE p.id = o.poll_id
      AND p.type = 'slider'
      AND o.content ~ '^[0-9]+$'
      AND o.id <> (
        SELECT min(o2.id) FROM poll_opts o2
        WHERE o2.poll_id = o.poll_id AND o2.content = o.content
      )
    """)

    repo().query!("""
    UPDATE poll_opts o
    SET rating_value = o.content::integer
    FROM polls p
    WHERE p.id = o.poll_id AND p.type = 'slider' AND o.content ~ '^[0-9]+$'
    """)
  end

  # Choice polls never used the range, so one saved outside the supported bounds
  # goes back to the default 1..10 rather than failing the constraint below.
  defp repair_impossible_ranges do
    repo().query!("""
    UPDATE polls
    SET min_value = 1, max_value = 10
    WHERE type <> 'slider'
      AND (min_value < 0 OR max_value > 100 OR min_value >= max_value)
    """)
  end
end
