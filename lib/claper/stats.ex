defmodule Claper.Stats do
  @moduledoc """
  The Stats context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  def distinct_poster_count(event_id) do
    from(posts in Claper.Posts.Post,
      where: posts.event_id == ^event_id,
      select: count(posts.user_id, :distinct) + count(posts.attendee_identifier, :distinct)
    )
    |> Repo.one()
  end

  def total_vote_count(presentation_file_id) do
    from(p in Claper.Polls.Poll,
      join: o in Claper.Polls.PollOpt,
      on: o.poll_id == p.id,
      where: p.presentation_file_id == ^presentation_file_id,
      group_by: o.poll_id,
      select: sum(o.vote_count)
    )
    |> Repo.all()
  end
end
