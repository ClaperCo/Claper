defmodule Claper.Repo.Migrations.AddNormalizedContentToPollOpts do
  use Ecto.Migration

  require Logger

  alias Claper.Polls.PollOpt

  # A word cloud merges the words attendees type case-insensitively, so it needs
  # exactly one row per word. Deciding that in application code -- look the word
  # up, then insert it -- lets two attendees who submit the same word at the same
  # moment each insert their own row. Storing the match key on the row lets the
  # database settle it instead.
  #
  # The key is filled in for word cloud options only. Options a presenter typed
  # on a choice poll keep a NULL key and stay outside the index, because
  # repeating the same text there has always been allowed and a unique index
  # over every poll_opt would fail on existing presentations.
  #
  # The keys are computed by `Claper.Polls.PollOpt.normalize/1`, the same
  # function the running application uses, rather than by a SQL expression that
  # restates the rule: `lower()` folds case by the database collation and
  # `btrim()` strips only ASCII spaces, so on a C-collation database the two
  # would disagree over a word like "ÄRGER" and the first submission after this
  # migration would open a second row for a word the cloud already holds.
  #
  # NOT REVERSIBLE AS DATA. `down/0` drops the index and the column, which is all
  # Ecto needs to migrate back, but it cannot undo `merge_split_words/1`: the
  # rows that duplicated a word are deleted, and their votes and counts have been
  # folded into the row that survived. Take a backup before running this if those
  # rows matter. Every merge is written to the log with both ids so that a
  # rollback at least leaves a record of what was folded into what.

  def up do
    alter table(:poll_opts) do
      add :normalized_content, :string
    end

    flush()

    keyed_word_cloud_options()
    |> merge_split_words()
    |> backfill_keys()

    create unique_index(:poll_opts, [:poll_id, :normalized_content],
             where: "normalized_content IS NOT NULL"
           )
  end

  def down do
    drop unique_index(:poll_opts, [:poll_id, :normalized_content],
           where: "normalized_content IS NOT NULL"
         )

    alter table(:poll_opts) do
      remove :normalized_content
    end
  end

  defp keyed_word_cloud_options do
    %{rows: rows} =
      repo().query!("""
      SELECT o.id, o.poll_id, o.content, o.vote_count
      FROM poll_opts o
      JOIN polls p ON p.id = o.poll_id
      WHERE p.type = 'word_cloud'
      ORDER BY o.id
      """)

    Enum.map(rows, fn [id, poll_id, content, vote_count] ->
      %{id: id, poll_id: poll_id, key: PollOpt.normalize(content), vote_count: vote_count || 0}
    end)
  end

  # Rows an unguarded submission may already have split apart: the oldest one
  # survives, the votes and the counts of the others move onto it.
  defp merge_split_words(options) do
    {survivors, duplicates} =
      options
      |> Enum.group_by(&{&1.poll_id, &1.key})
      |> Map.values()
      |> Enum.reduce({[], []}, fn [keeper | rest], {survivors, duplicates} ->
        {[keeper | survivors], Enum.map(rest, &Map.put(&1, :keep_id, keeper.id)) ++ duplicates}
      end)

    fold_duplicates_into_survivors(duplicates)

    survivors
  end

  defp fold_duplicates_into_survivors([]), do: :ok

  defp fold_duplicates_into_survivors(duplicates) do
    Enum.each(duplicates, fn duplicate ->
      Logger.info(
        "poll_opts: folding row #{duplicate.id} (#{duplicate.vote_count} votes) into row " <>
          "#{duplicate.keep_id}; the two hold the same word for poll #{duplicate.poll_id}. " <>
          "This cannot be undone by rolling the migration back."
      )
    end)

    ids = Enum.map(duplicates, & &1.id)
    keep_ids = Enum.map(duplicates, & &1.keep_id)

    repo().query!(
      """
      UPDATE poll_votes
      SET poll_opt_id = folded.keep_id
      FROM (SELECT unnest($1::bigint[]) AS id, unnest($2::bigint[]) AS keep_id) AS folded
      WHERE poll_votes.poll_opt_id = folded.id
      """,
      [ids, keep_ids]
    )

    extra_votes = Enum.group_by(duplicates, & &1.keep_id, & &1.vote_count)

    repo().query!(
      """
      UPDATE poll_opts
      SET vote_count = poll_opts.vote_count + folded.extra_votes
      FROM (SELECT unnest($1::bigint[]) AS keep_id, unnest($2::bigint[]) AS extra_votes) AS folded
      WHERE poll_opts.id = folded.keep_id
      """,
      [Map.keys(extra_votes), extra_votes |> Map.values() |> Enum.map(&Enum.sum/1)]
    )

    repo().query!("DELETE FROM poll_opts WHERE id = ANY($1::bigint[])", [ids])
  end

  defp backfill_keys([]), do: :ok

  defp backfill_keys(options) do
    repo().query!(
      """
      UPDATE poll_opts
      SET normalized_content = keyed.key
      FROM (SELECT unnest($1::bigint[]) AS id, unnest($2::text[]) AS key) AS keyed
      WHERE poll_opts.id = keyed.id
      """,
      [Enum.map(options, & &1.id), Enum.map(options, & &1.key)]
    )
  end
end
