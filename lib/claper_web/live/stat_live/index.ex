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
        presentation_file: [
          polls: [:poll_opts],
          stories: [:story_opts],
          forms: [:form_submits],
          embeds: [],
          quizzes: [:quiz_questions, quiz_questions: :quiz_question_opts]
        ]
      )

    # Calculate percentages for each quiz
    event = %{
      event
      | presentation_file: %{
          event.presentation_file
          | quizzes: Enum.map(event.presentation_file.quizzes, &Claper.Quizzes.set_percentages/1)
        }
    }

    distinct_attendee_count = Claper.Stats.get_unique_attendees_for_event(event.id)
    distinct_poster_count = Claper.Stats.distinct_poster_count(event.id)

    {:ok,
     socket
     |> assign(:event, event)
     |> assign(
       :distinct_poster_count,
       distinct_poster_count
     )
     |> assign(
       :distinct_attendee_count,
       distinct_attendee_count
     )
     |> assign(
       :engagement_rate,
       calculate_engagement_rate(event, distinct_attendee_count)
     )
     |> assign(:posts, list_posts(socket, event.uuid))
     |> assign(:current_tab, :messages)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Report"))
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, String.to_existing_atom(tab))}
  end

  defp calculate_engagement_rate(event, unique_attendees) do
    total =
      average_messages(event, unique_attendees) + average_polls(event, unique_attendees) +
        average_quizzes(event, unique_attendees) + average_forms(event, unique_attendees) +
        average_stories(event, unique_attendees)

    (total / 4 * 100)
    |> Float.round()
    |> :erlang.float_to_binary(decimals: 0)
    |> :erlang.binary_to_integer()
  end

  defp average_messages(_event, 0), do: 0

  defp average_messages(event, unique_attendees) do
    distinct_poster_count = Claper.Stats.distinct_poster_count(event.id)
    distinct_poster_count / unique_attendees
  end

  defp average_polls(_event, 0), do: 0

  defp average_polls(event, unique_attendees) do
    poll_ids = Claper.Polls.list_polls(event.presentation_file.id) |> Enum.map(& &1.id)

    case poll_ids do
      [] ->
        0

      poll_ids ->
        distinct_votes = Claper.Stats.get_distinct_poll_votes(poll_ids)
        distinct_votes / (Enum.count(poll_ids) * unique_attendees)
    end
  end

  defp average_stories(_event, 0), do: 0

  defp average_stories(event, unique_attendees) do
    story_ids = Claper.Stories.list_stories(event.presentation_file.id) |> Enum.map(& &1.id)

    case story_ids do
      [] ->
        0

      story_ids ->
        distinct_votes = Claper.Stats.get_distinct_story_votes(story_ids)
        distinct_votes / (Enum.count(story_ids) * unique_attendees)
    end
  end

  defp average_quizzes(_event, 0), do: 0

  defp average_quizzes(event, unique_attendees) do
    quiz_ids = Claper.Quizzes.list_quizzes(event.presentation_file.id) |> Enum.map(& &1.id)

    case quiz_ids do
      [] ->
        0

      quiz_ids ->
        distinct_votes = Claper.Stats.get_distinct_quiz_responses(quiz_ids)
        distinct_votes / (Enum.count(quiz_ids) * unique_attendees)
    end
  end

  defp average_forms(_event, 0), do: 0

  defp average_forms(event, unique_attendees) do
    form_ids = Claper.Forms.list_forms(event.presentation_file.id) |> Enum.map(& &1.id)

    case form_ids do
      [] ->
        0

      form_ids ->
        distinct_submits = Claper.Stats.get_distinct_form_submits(form_ids)
        distinct_submits / (Enum.count(form_ids) * unique_attendees)
    end
  end

  defp list_posts(_socket, event_id) do
    Claper.Posts.list_posts(event_id, [:event, :reactions])
  end
end
