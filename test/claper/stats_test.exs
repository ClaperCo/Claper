defmodule Claper.StatsTest do
  use Claper.DataCase

  import Claper.{PollsFixtures, PostsFixtures, PresentationsFixtures}

  alias Claper.Stats

  test "report_summary/1 returns the audience, messages and engagement of an event" do
    presentation_file = presentation_file_fixture(%{}, [:event])
    {:ok, event} = Claper.Events.update_event(presentation_file.event, %{audience_peak: 9})

    for attendee <- ~w(a b c d), do: Stats.create_stat(event, %{attendee_identifier: attendee})

    post_fixture(%{event: event})
    post_fixture(%{event: event})

    poll = poll_fixture(%{presentation_file_id: presentation_file.id})
    [option | _] = poll.poll_opts
    poll_vote_fixture(%{poll_id: poll.id, poll_opt_id: option.id, attendee_identifier: "a"})

    # Engagement: 2 posters of 4 attendees, 1 voter of 4 on the only poll,
    # nothing on quizzes, forms and word clouds: (1/2 + 1/4) / 5.
    assert Stats.report_summary(event) == %{
             audience_peak: 9,
             unique_attendees: 4,
             messages: 2,
             engagement_rate: 15
           }
  end
end
