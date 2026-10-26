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
        multiple: false,
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

    identity = attrs[:user_id] || attrs[:attendee_identifier] || user_fixture().id
    poll_id = attrs[:poll_id] || poll.id
    option_id = attrs[:poll_opt_id] || poll_opt.id
    option = Claper.Repo.get!(Claper.Polls.PollOpt, option_id)
    {:ok, _} = Claper.Polls.vote(identity, "fixture", [option], poll_id)
    [poll_vote] = Claper.Polls.get_poll_vote(identity, poll_id)

    poll_vote
  end
end
