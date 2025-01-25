defmodule Claper.Stats do
  @moduledoc """
  All calculation for stats related to an event
  """

  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Claper.Stats.Stat

  def create_stat(event, attrs) do
    %Stat{}
    |> Map.put(:event, event)
    |> Stat.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing)
  end

  def get_unique_attendees_for_event(event_id) do
    from(s in Stat,
      where: s.event_id == ^event_id,
      select:
        count(
          fragment("DISTINCT COALESCE(?, CAST(? AS varchar))", s.attendee_identifier, s.user_id)
        )
    )
    |> Repo.one()
  end

  def get_distinct_poll_votes(poll_ids) do
    from(pv in Claper.Polls.PollVote,
      where: pv.poll_id in ^poll_ids,
      group_by: pv.poll_id,
      select: %{
        poll_id: pv.poll_id,
        count:
          count(
            fragment(
              "DISTINCT COALESCE(?, CAST(? AS varchar))",
              pv.attendee_identifier,
              pv.user_id
            )
          )
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  def get_distinct_story_votes(story_ids) do
    from(pv in Claper.Stories.StoryVote,
      where: pv.story_id in ^story_ids,
      group_by: pv.story_id,
      select: %{
        story_id: pv.story_id,
        count:
          count(
            fragment(
              "DISTINCT COALESCE(?, CAST(? AS varchar))",
              pv.attendee_identifier,
              pv.user_id
            )
          )
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  def get_distinct_quiz_responses(quiz_ids) do
    from(pv in Claper.Quizzes.QuizResponse,
      where: pv.quiz_id in ^quiz_ids,
      group_by: pv.quiz_id,
      select: %{
        quiz_id: pv.quiz_id,
        count:
          count(
            fragment(
              "DISTINCT COALESCE(?, CAST(? AS varchar))",
              pv.attendee_identifier,
              pv.user_id
            )
          )
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  def get_distinct_form_submits(form_ids) do
    from(pv in Claper.Forms.FormSubmit,
      where: pv.form_id in ^form_ids,
      group_by: pv.form_id,
      select: %{
        form_id: pv.form_id,
        count:
          count(
            fragment(
              "DISTINCT COALESCE(?, CAST(? AS varchar))",
              pv.attendee_identifier,
              pv.user_id
            )
          )
      }
    )
    |> Repo.all()
    |> Enum.map(fn %{count: count} -> count end)
    |> Enum.sum()
  end

  def distinct_poster_count(event_id) do
    from(posts in Claper.Posts.Post,
      where: posts.event_id == ^event_id,
      select: count(posts.user_id, :distinct) + count(posts.attendee_identifier, :distinct)
    )
    |> Repo.one()
  end

  def total_vote_count(presentation_file_id) do
    from(p in Claper.Polls.Poll,
      join: pv in Claper.Polls.PollVote,
      on: pv.poll_id == p.id,
      where: p.presentation_file_id == ^presentation_file_id,
      group_by: p.presentation_file_id,
      select:
        count(
          fragment("DISTINCT COALESCE(?, CAST(? AS varchar))", pv.attendee_identifier, pv.user_id)
        )
    )
    |> Repo.all()
  end
end
