defmodule Claper.PollsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Polls` context.
  """

  import Claper.{AccountsFixtures, PresentationsFixtures}

  require Claper.UtilFixture

  @doc """
  Generate a poll.
  """
  def poll_fixture(attrs \\ %{}, preload \\ []) do
    attrs =
      Enum.into(attrs, %{
        title: "some title",
        position: 0,
        multiple: false,
        enabled: true,
        poll_opts: [
          %{content: "some option 1", vote_count: 0},
          %{content: "some option 2", vote_count: 0}
        ]
      })

    {words, attrs} = split_off_word_cloud_words(attrs)

    {:ok, poll} = Claper.Polls.create_poll(attrs)

    poll = collect_words(poll, words, attrs)

    Claper.UtilFixture.merge_preload(poll, preload, %{})
  end

  # A word cloud's options are not something a form or a context call can create:
  # they are the words attendees typed, each carrying the match key that
  # `Claper.Polls.submit_word/4` writes. Handing them to `create_poll/1` would
  # build a poll the application itself can no longer produce -- word cloud rows
  # with a NULL key, which the unique index behind "one row per word" does not
  # cover -- so the fixture submits them the way an audience would.
  defp split_off_word_cloud_words(attrs) do
    if to_string(Map.get(attrs, :type, :choice)) == "word_cloud" do
      {Map.get(attrs, :poll_opts, []), Map.put(attrs, :poll_opts, [])}
    else
      {[], attrs}
    end
  end

  defp collect_words(poll, [], _attrs), do: poll

  defp collect_words(poll, words, attrs) do
    event_uuid =
      Claper.Repo.preload(poll, presentation_file: :event).presentation_file.event.uuid

    # Only an enabled cloud takes words, so a fixture for a closed one collects
    # its words first and closes afterwards.
    {:ok, _} = Claper.Polls.set_enabled(poll.id)

    for word <- words, vote <- 1..Map.get(word, :vote_count, 1)//1 do
      {:ok, _} =
        Claper.Polls.submit_word(
          "fixture-#{word.content}-#{vote}",
          event_uuid,
          poll.id,
          word.content
        )
    end

    if Map.get(attrs, :enabled) != true, do: {:ok, _} = Claper.Polls.set_disabled(poll.id)

    poll
    |> Claper.Repo.preload([:poll_opts], force: true)
    |> Map.put(:enabled, Map.get(attrs, :enabled))
  end

  @doc """
  Generate a poll_vote.
  """
  def poll_vote_fixture(attrs \\ %{}) do
    presentation_file = presentation_file_fixture()
    poll = poll_fixture(%{presentation_file_id: presentation_file.id})
    [poll_opt | _] = poll.poll_opts
    assoc = %{poll: poll}

    {:ok, poll_vote} =
      attrs
      |> Enum.into(%{
        poll_id: assoc.poll.id,
        poll_opt_id: poll_opt.id,
        user_id: user_fixture().id
      })
      |> Claper.Polls.create_poll_vote()

    poll_vote
  end
end
