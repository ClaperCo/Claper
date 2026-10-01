defmodule ClaperWeb.StatLive.Index do
  use ClaperWeb, :live_view

  alias Claper.{Events, Transcriptions}

  @transcriptions_page_size 25
  @avatars ~w(🦊 🐙 🦉 🐸 🐼 🦋 🐬 🦈 🐢 🦎 🐝 🦩 🐧 🦦 🐨 🦁 🐯 🐻 🐰 🐮
    🐷 🐵 🦄 🐺 🦇 🐳 🐠 🦑 🦞 🦀 🐡 🐞 🦗 🕷 🦂 🐍 🦕 🦖 🦚 🦜
    🦢 🦩 🐓 🦃 🦆 🦅 🦔 🐿 🦫 🦨 🦡 🦝 🦥 🦘 🦙 🐫 🐘 🦏 🦛 🐊
    🐅 🐆 🦓 🐃 🐂 🐄 🐎 🐖 🐑 🐐 🦌 🐕 🐈 🦮 🐁 🐀 🦔 🐲 🌵 🍄)

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
    posts = list_posts(socket, event.uuid)

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
     |> assign(:posts, posts)
     |> assign(:current_tab, :messages)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> apply_action(socket.assigns.live_action, params)
     |> load_transcriptions()}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Report"))
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab_to_atom(tab))}
  end

  @impl true
  def handle_event("load_more_transcriptions", _params, socket) do
    next_page = (socket.assigns.transcriptions_meta.current_page || 1) + 1

    {transcriptions, transcriptions_meta} =
      paginated_transcriptions(socket.assigns.event.presentation_file.id, next_page)

    {:noreply,
     socket
     |> assign(:transcriptions, socket.assigns.transcriptions ++ transcriptions)
     |> assign(:transcriptions_meta, transcriptions_meta)}
  end

  defp tab_to_atom("messages"), do: :messages
  defp tab_to_atom("polls"), do: :polls
  defp tab_to_atom("forms"), do: :forms
  defp tab_to_atom("web_content"), do: :web_content
  defp tab_to_atom("quizzes"), do: :quizzes
  defp tab_to_atom("transcriptions"), do: :transcriptions
  defp tab_to_atom(_), do: :messages

  defp available_tabs(event, posts, has_transcriptions?) do
    [
      {:messages, posts},
      {:polls, event.presentation_file.polls},
      {:forms, event.presentation_file.forms},
      {:web_content, event.presentation_file.embeds},
      {:quizzes, event.presentation_file.quizzes},
      {:transcriptions, has_transcriptions?}
    ]
    |> Enum.filter(fn
      {_tab, entries} when is_list(entries) -> entries != []
      {_tab, has_entries?} -> has_entries?
    end)
    |> Enum.map(fn {tab, _entries} -> tab end)
  end

  defp load_transcriptions(socket) do
    {transcriptions, transcriptions_meta} =
      paginated_transcriptions(socket.assigns.event.presentation_file.id, 1)

    available_tabs =
      available_tabs(
        socket.assigns.event,
        socket.assigns.posts,
        transcriptions_meta.total_count > 0
      )

    socket
    |> assign(:transcriptions, transcriptions)
    |> assign(:transcriptions_meta, transcriptions_meta)
    |> assign(:available_tabs, available_tabs)
    |> assign(:current_tab, current_tab(socket, available_tabs))
  end

  defp paginated_transcriptions(presentation_file_id, page) do
    Transcriptions.list_transcriptions_paginated(presentation_file_id, %{
      "page" => page,
      "page_size" => @transcriptions_page_size
    })
  end

  defp current_tab(socket, available_tabs) do
    if socket.assigns.current_tab in available_tabs do
      socket.assigns.current_tab
    else
      List.first(available_tabs) || :messages
    end
  end

  defp calculate_engagement_rate(event, unique_attendees) do
    total =
      average_messages(event, unique_attendees) + average_polls(event, unique_attendees) +
        average_quizzes(event, unique_attendees) + average_forms(event, unique_attendees)

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

  defp avatar_identifier(record) do
    "#{record.attendee_identifier || record.user_id || "default"}"
  end

  defp avatar_color(record) do
    hue = :erlang.phash2(avatar_identifier(record), 360)
    "hsl(#{hue}, 45%, 55%)"
  end

  defp avatar_emoji(record) do
    index = :erlang.phash2({avatar_identifier(record), :emoji}, length(@avatars))
    Enum.at(@avatars, index)
  end
end
