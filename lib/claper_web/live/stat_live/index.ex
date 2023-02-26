defmodule ClaperWeb.StatLive.Index do
  use ClaperWeb, :live_view

  alias Claper.Events

  on_mount(ClaperWeb.UserLiveAuth)

  @impl true
  def mount(%{"id" => id}, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    event =
      Events.get_managed_event!(socket.assigns.current_user, id,
        presentation_file: [polls: [:poll_opts], forms: [:form_submits]]
      )

    grouped_total_votes = Claper.Stats.total_vote_count(event.presentation_file.id)
    distinct_poster_count = Claper.Stats.distinct_poster_count(event.id)

    {:ok,
     socket
     |> assign(:event, event)
     |> assign(
       :distinct_poster_count,
       distinct_poster_count
     )
     |> assign(
       :grouped_total_votes,
       grouped_total_votes
     )
     |> assign(:average_voters, average_voters(grouped_total_votes))
     |> assign(
       :engagement_rate,
       calculate_engagement_rate(grouped_total_votes, distinct_poster_count, event)
     )
     |> assign(:posts, list_posts(socket, event.uuid))
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Report")
  end

  defp calculate_engagement_rate(grouped_total_votes, distinct_poster_count, event) do
    total_polls = Enum.count(grouped_total_votes)

    if total_polls == 0 do
      (distinct_poster_count / event.audience_peak * 100)
      |> Float.round()
      |> :erlang.float_to_binary(decimals: 0)
      |> :erlang.binary_to_integer()
    else
      ((distinct_poster_count / event.audience_peak +
          average_voters(grouped_total_votes) / event.audience_peak) / 2 * 100)
      |> Float.round()
      |> :erlang.float_to_binary(decimals: 0)
      |> :erlang.binary_to_integer()
    end
  end

  defp average_voters(grouped_total_votes) do
    total_polls = Enum.count(grouped_total_votes)

    if total_polls == 0 do
      0
    else
      (Enum.sum(grouped_total_votes) / total_polls)
      |> Float.round()
      |> :erlang.float_to_binary(decimals: 0)
      |> :erlang.binary_to_integer()
    end
  end

  defp list_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end
end
