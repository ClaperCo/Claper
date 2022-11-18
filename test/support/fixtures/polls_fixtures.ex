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
    {:ok, poll} =
      attrs
      |> Enum.into(%{
        title: "some title",
        position: 0,
        enabled: true,
        poll_opts: [
          %{content: "some option 1", vote_count: 0},
          %{content: "some option 2", vote_count: 0}
        ]
      })
      |> Claper.Polls.create_poll()

    Claper.UtilFixture.merge_preload(poll, preload, %{})
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
