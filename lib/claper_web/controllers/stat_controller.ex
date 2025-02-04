defmodule ClaperWeb.StatController do
  @moduledoc """
  Controller responsible for exporting various statistics and data in CSV format.
  Handles form submissions, messages, and poll results exports.
  """
  use ClaperWeb, :controller

  alias Claper.{Forms, Events, Polls, Stories, Presentations, Quizzes}

  @doc """
  Exports form submissions as a CSV file.
  """
  def export_form(conn, %{"form_id" => form_id}) do
    form = Forms.get_form!(form_id, [:form_submits])
    headers = form.fields |> Enum.map(& &1.name)

    data =
      form.form_submits
      |> Enum.map(fn submit ->
        form.fields
        |> Enum.map(fn field ->
          Map.get(submit.response, field.name, "")
        end)
      end)

    export_as_csv(conn, headers, data, "form-#{sanitize(form.title)}")
  end

  @doc """
  Exports all messages from an event as a CSV file.
  Requires user to be either an event leader or the event owner.
  """
  def export_all_messages(%{assigns: %{current_user: current_user}} = conn, %{
        "event_id" => event_id
      }) do
    event = Events.get_event!(event_id, posts: [:user])

    case authorize_event_access(current_user, event) do
      :ok ->
        headers = [
          "Attendee identifier",
          "User email",
          "Name",
          "Message",
          "Pinned",
          "Slide #",
          "Sent at (UTC)"
        ]

        content = format_messages_for_export(event.posts)

        export_as_csv(conn, headers, content, "messages-#{sanitize(event.name)}")

      :unauthorized ->
        send_resp(conn, 403, "Forbidden")
    end
  end

  @doc """
  Exports poll results as a CSV file.
  Requires user to be either an event leader or the event owner.
  """
  def export_poll(%{assigns: %{current_user: current_user}} = conn, %{"poll_id" => poll_id}) do
    with poll <- Polls.get_poll!(poll_id),
         presentation_file <-
           Presentations.get_presentation_file!(poll.presentation_file_id, [:event]),
         event <- presentation_file.event,
         :ok <- authorize_event_access(current_user, event) do
      headers = ["Name", "Multiple choice", "Slide #"] ++ Enum.map(poll.poll_opts, & &1.content)

      content =
        [poll.title, poll.multiple, poll.position + 1] ++
          Enum.map(poll.poll_opts, & &1.vote_count)

      export_as_csv(conn, headers, [content], "poll-#{sanitize(poll.title)}")
    else
      :unauthorized -> send_resp(conn, 403, "Forbidden")
    end
  end

  @doc """
  Exports story results as a CSV file.
  Requires user to be either an event leader or the event owner.
  """
  def export_story(%{assigns: %{current_user: current_user}} = conn, %{"story_id" => story_id}) do
    with story <- Stories.get_story!(story_id),
         presentation_file <-
           Presentations.get_presentation_file!(story.presentation_file_id, [:event]),
         event <- presentation_file.event,
         :ok <- authorize_event_access(current_user, event) do
      headers = ["Name", "Multiple choice", "Slide #"] ++ Enum.map(story.story_opts, & &1.content)

      content =
        [story.title, story.multiple, story.position + 1] ++
          Enum.map(story.story_opts, & &1.vote_count)

      export_as_csv(conn, headers, [content], "story-#{sanitize(story.title)}")
    else
      :unauthorized -> send_resp(conn, 403, "Forbidden")
    end
  end

  @doc """
  Exports quiz results as a CSV file.
  Requires user to be either an event leader or the event owner.
  """
  def export_quiz(%{assigns: %{current_user: current_user}} = conn, %{"quiz_id" => quiz_id}) do
    with quiz <-
           Quizzes.get_quiz!(quiz_id, [
             :quiz_questions,
             :quiz_responses,
             quiz_questions: :quiz_question_opts,
             quiz_responses: [:quiz_question_opt, :user],
             presentation_file: :event
           ]),
         event <- quiz.presentation_file.event,
         :ok <- authorize_event_access(current_user, event) do
      questions = quiz.quiz_questions
      headers = build_quiz_headers(questions)

      # Group responses by user/attendee and question
      responses_by_user =
        Enum.group_by(
          quiz.quiz_responses,
          fn response -> response.user_id || response.attendee_identifier end
        )

      # Format data rows - one row per user with their answers and score
      data = Enum.map(responses_by_user, &process_user_responses(&1, questions))

      csv_content =
        CSV.encode([headers | data])
        |> Enum.to_list()
        |> to_string()

      send_download(conn, {:binary, csv_content},
        filename: "quiz_#{quiz.id}_results.csv",
        content_type: "text/csv"
      )
    end
  end

  defp build_quiz_headers(questions) do
    question_headers =
      questions
      |> Enum.with_index(1)
      |> Enum.map(fn {question, _index} -> question.content end)

    ["Attendee identifier", "User email"] ++ question_headers ++ ["Total"]
  end

  defp process_user_responses({_user_id, responses}, questions) do
    user_identifier = format_attendee_identifier(List.first(responses).attendee_identifier)
    user_email = Map.get(List.first(responses).user || %{}, :email, "N/A")
    responses_by_question = Enum.group_by(responses, & &1.quiz_question_id)

    answers_with_correctness = process_question_responses(questions, responses_by_question)
    answers = Enum.map(answers_with_correctness, fn {answer, _} -> answer || "" end)
    correct_count = Enum.count(answers_with_correctness, fn {_, correct} -> correct end)
    total = "#{correct_count}/#{length(questions)}"

    [user_identifier, user_email] ++ answers ++ [total]
  end

  defp process_question_responses(questions, responses_by_question) do
    Enum.map(questions, fn question ->
      question_responses = Map.get(responses_by_question, question.id, [])

      correct_opt_ids =
        question.quiz_question_opts
        |> Enum.filter(& &1.is_correct)
        |> Enum.map(& &1.id)
        |> MapSet.new()

      format_question_response(question_responses, correct_opt_ids)
    end)
  end

  defp format_question_response([], _correct_opt_ids), do: {nil, false}

  defp format_question_response(question_responses, correct_opt_ids) do
    answers = Enum.map(question_responses, & &1.quiz_question_opt.content)

    all_correct =
      Enum.all?(question_responses, fn r ->
        MapSet.member?(correct_opt_ids, r.quiz_question_opt_id)
      end)

    {Enum.join(answers, ", "), all_correct}
  end

  @doc """
  Exports quiz as QTI format.
  Requires user to be either an event leader or the event owner.
  """
  def export_quiz_qti(%{assigns: %{current_user: current_user}} = conn, %{"quiz_id" => quiz_id}) do
    with quiz <-
           Quizzes.get_quiz!(quiz_id, [
             :quiz_questions,
             quiz_questions: :quiz_question_opts,
             presentation_file: :event
           ]),
         event <- quiz.presentation_file.event,
         :ok <- authorize_event_access(current_user, event) do
      qti_content = generate_qti_content(quiz)

      conn
      |> put_resp_content_type("application/xml")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="#{sanitize(quiz.title)}_qti.xml")
      )
      |> send_resp(200, qti_content)
    else
      :unauthorized -> send_resp(conn, 403, "Forbidden")
    end
  end

  # Private functions

  defp authorize_event_access(user, event) do
    if Events.leaded_by?(user.email, event) || event.user_id == user.id do
      :ok
    else
      :unauthorized
    end
  end

  defp format_messages_for_export(posts) do
    posts
    |> Enum.map(fn post ->
      [
        format_attendee_identifier(post.attendee_identifier),
        format_user_email(post.user),
        post.name || "N/A",
        post.body,
        post.pinned,
        post.position + 1,
        post.inserted_at
      ]
    end)
  end

  defp format_attendee_identifier(nil), do: "N/A"
  defp format_attendee_identifier(identifier), do: Base.encode16(identifier)

  defp format_user_email(nil), do: "N/A"
  defp format_user_email(user), do: user.email

  defp export_as_csv(conn, headers, data, filename) do
    csv_data =
      ([headers] ++ data)
      |> CSV.encode()
      |> Enum.to_list()
      |> to_string()

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}.csv\"")
    |> put_root_layout(false)
    |> send_resp(200, csv_data)
  end

  defp generate_qti_content(quiz) do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <questestinterop xmlns="http://www.imsglobal.org/xsd/ims_qtiasiv1p2">
      <assessment title="#{quiz.title}">
        <section>
          #{Enum.map_join(quiz.quiz_questions, "\n", &generate_qti_item/1)}
        </section>
      </assessment>
    </questestinterop>
    """
  end

  defp generate_qti_item(question) do
    """
      <item>
        <presentation>
          <material>
            <mattext>#{question.content}</mattext>
          </material>
          <response_lid ident="RESPONSE" rcardinality="Multiple">
            <render_choice>
              #{Enum.map_join(question.quiz_question_opts, "\n", &generate_qti_option/1)}
            </render_choice>
          </response_lid>
        </presentation>
        <resprocessing>
          <outcomes>
            <decvar vartype="Integer" defaultval="0"/>
          </outcomes>
          #{Enum.map_join(question.quiz_question_opts, "\n", &generate_qti_condition/1)}
        </resprocessing>
      </item>
    """
  end

  defp generate_qti_option(option) do
    """
              <response_label ident="#{option.id}">
                <material>
                  <mattext>#{option.content}</mattext>
                </material>
              </response_label>
    """
  end

  defp generate_qti_condition(option) do
    if option.is_correct do
      """
          <respcondition>
            <conditionvar>
              <varequal respident="RESPONSE">#{option.id}</varequal>
            </conditionvar>
            <setvar action="Set">1</setvar>
          </respcondition>
      """
    else
      ""
    end
  end

  defp sanitize(string),
    do: string |> String.replace(~r/[^\w\s-]/, "") |> String.replace(~r/\s+/, "-")
end
