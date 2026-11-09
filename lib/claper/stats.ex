defmodule Claper.Stats do
  @moduledoc """
  All calculation for stats related to an event
  """

  import Ecto.Query, warn: false
  alias Claper.Events.Event
  alias Claper.Forms.Form
  alias Claper.Polls.Poll
  alias Claper.Posts.Post
  alias Claper.Presentations.PresentationFile
  alias Claper.Quizzes.Quiz
  alias Claper.Repo
  alias Claper.Stats.Stat
  alias Claper.WordClouds.WordCloud

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
              "DISTINCT ROW(?, ?)",
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
              "DISTINCT ROW(?, ?)",
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

  def get_distinct_word_cloud_entries(word_cloud_ids) do
    from(e in Claper.WordClouds.Entry,
      where: e.word_cloud_id in ^word_cloud_ids,
      group_by: e.word_cloud_id,
      select: %{
        word_cloud_id: e.word_cloud_id,
        count:
          count(
            fragment(
              "DISTINCT COALESCE(?, CAST(? AS varchar))",
              e.attendee_identifier,
              e.user_id
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
      select: count(fragment("DISTINCT ROW(?, ?)", pv.attendee_identifier, pv.user_id))
    )
    |> Repo.all()
  end

  @doc """
  Returns the figures shown at the top of an event's report.
  """
  def report_summary(%Event{id: event_id, audience_peak: audience_peak}) do
    unique_attendees = get_unique_attendees_for_event(event_id)

    presentation_file_id =
      from(f in PresentationFile, where: f.event_id == ^event_id, select: f.id, limit: 1)
      |> Repo.one()

    %{
      audience_peak: audience_peak,
      unique_attendees: unique_attendees,
      messages: from(p in Post, where: p.event_id == ^event_id) |> Repo.aggregate(:count),
      engagement_rate: engagement_rate(event_id, presentation_file_id, unique_attendees)
    }
  end

  @doc """
  Returns the engagement rate of an event, in percent: the share of its unique attendees
  who took part in messages, polls, quizzes, forms and word clouds, averaged over the five.
  """
  def engagement_rate(_event_id, _presentation_file_id, 0), do: 0

  def engagement_rate(event_id, presentation_file_id, unique_attendees) do
    shares = [
      distinct_poster_count(event_id) / unique_attendees,
      participation(
        &get_distinct_poll_votes/1,
        interaction_ids(Poll, presentation_file_id),
        unique_attendees
      ),
      participation(
        &get_distinct_quiz_responses/1,
        interaction_ids(Quiz, presentation_file_id),
        unique_attendees
      ),
      participation(
        &get_distinct_form_submits/1,
        interaction_ids(Form, presentation_file_id),
        unique_attendees
      ),
      participation(
        &get_distinct_word_cloud_entries/1,
        interaction_ids(WordCloud, presentation_file_id),
        unique_attendees
      )
    ]

    round(Enum.sum(shares) / length(shares) * 100)
  end

  defp participation(_count_participants, [], _unique_attendees), do: 0

  defp participation(count_participants, ids, unique_attendees),
    do: count_participants.(ids) / (length(ids) * unique_attendees)

  defp interaction_ids(_schema, nil), do: []

  defp interaction_ids(schema, presentation_file_id) do
    from(i in schema, where: i.presentation_file_id == ^presentation_file_id, select: i.id)
    |> Repo.all()
  end
end
