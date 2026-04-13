defmodule Claper.Interactions do
  alias Claper.Polls
  alias Claper.Forms
  alias Claper.Embeds
  alias Claper.Events
  alias Claper.Presentations
  alias Claper.Quizzes
  import Ecto.Query, warn: false

  @type interaction :: Polls.Poll | Forms.Form | Embeds.Embed | Quizzes.Quiz

  def get_number_total_interactions(presentation_file_id) do
    from(p in Polls.Poll,
      where: p.presentation_file_id == ^presentation_file_id,
      select: count(p.id)
    )
    |> Claper.Repo.one()
    |> Kernel.+(
      from(f in Forms.Form,
        where: f.presentation_file_id == ^presentation_file_id,
        select: count(f.id)
      )
      |> Claper.Repo.one()
    )
    |> Kernel.+(
      from(e in Embeds.Embed,
        where: e.presentation_file_id == ^presentation_file_id,
        select: count(e.id)
      )
      |> Claper.Repo.one()
    )
    |> Kernel.+(
      from(q in Quizzes.Quiz,
        where: q.presentation_file_id == ^presentation_file_id,
        select: count(q.id)
      )
      |> Claper.Repo.one()
    )
  end

  def get_active_interaction(event, position) do
    with {:ok, interactions} <- get_interactions_at_position(event, position) do
      interactions |> Enum.filter(&(&1.enabled == true)) |> List.first()
    end
  end

  def get_interactions_at_position(
        %Events.Event{
          presentation_file: %Presentations.PresentationFile{id: presentation_file_id}
        } = event,
        position,
        broadcast \\ false
      ) do
    with polls <- Polls.list_polls_at_position(presentation_file_id, position),
         forms <- Forms.list_forms_at_position(presentation_file_id, position),
         embeds <- Embeds.list_embeds_at_position(presentation_file_id, position),
         quizzes <- Quizzes.list_quizzes_at_position(presentation_file_id, position) do
      interactions =
        (polls ++ forms ++ embeds ++ quizzes)
        |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})

      if broadcast do
        active_interaction = interactions |> Enum.filter(&(&1.enabled == true)) |> List.first()

        Phoenix.PubSub.broadcast(
          Claper.PubSub,
          "event:#{event.uuid}",
          {:current_interaction, active_interaction}
        )
      end

      {:ok, interactions}
    end
  end

  def enable_interaction(interaction) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:disable_polls, fn _repo, _ ->
      {count, _} = Polls.disable_all(interaction.presentation_file_id, interaction.position)
      {:ok, count}
    end)
    |> Ecto.Multi.run(:disable_forms, fn _repo, _ ->
      {count, _} = Forms.disable_all(interaction.presentation_file_id, interaction.position)
      {:ok, count}
    end)
    |> Ecto.Multi.run(:disable_embeds, fn _repo, _ ->
      {count, _} = Embeds.disable_all(interaction.presentation_file_id, interaction.position)
      {:ok, count}
    end)
    |> Ecto.Multi.run(:disable_quizzes, fn _repo, _ ->
      {count, _} = Quizzes.disable_all(interaction.presentation_file_id, interaction.position)
      {:ok, count}
    end)
    |> Ecto.Multi.run(:enable_interaction, fn _repo, _ ->
      set_enabled(interaction)
    end)
    |> Claper.Repo.transaction()
    |> case do
      {:ok, _} -> :ok
      {:error, _, reason, _} -> {:error, reason}
    end
  end

  defp set_enabled(%Polls.Poll{} = interaction) do
    Polls.set_enabled(interaction.id)
  end

  defp set_enabled(%Forms.Form{} = interaction) do
    Forms.set_enabled(interaction.id)
  end

  defp set_enabled(%Embeds.Embed{} = interaction) do
    Embeds.set_enabled(interaction.id)
  end

  defp set_enabled(%Quizzes.Quiz{} = interaction) do
    Quizzes.set_enabled(interaction.id)
  end

  def disable_interaction(%Polls.Poll{} = interaction) do
    Polls.set_disabled(interaction.id)
  end

  def disable_interaction(%Forms.Form{} = interaction) do
    Forms.set_disabled(interaction.id)
  end

  def disable_interaction(%Embeds.Embed{} = interaction) do
    Embeds.set_disabled(interaction.id)
  end

  def disable_interaction(%Quizzes.Quiz{} = interaction) do
    Quizzes.set_disabled(interaction.id)
  end

  def duplicate_interaction(%Polls.Poll{} = poll) do
    poll = Polls.get_poll!(poll.id)

    Polls.create_poll(%{
      title: duplicate_title(poll.title),
      position: poll.position,
      enabled: false,
      multiple: poll.multiple,
      show_results: poll.show_results,
      presentation_file_id: poll.presentation_file_id,
      poll_opts:
        Enum.map(poll.poll_opts, fn opt ->
          %{
            content: opt.content,
            vote_count: 0
          }
        end)
    })
  end

  def duplicate_interaction(%Forms.Form{} = form) do
    form = Forms.get_form!(form.id)

    Forms.create_form(%{
      title: duplicate_title(form.title),
      position: form.position,
      enabled: false,
      presentation_file_id: form.presentation_file_id,
      fields:
        Enum.map(form.fields, fn field ->
          %{
            name: field.name,
            type: field.type,
            required: field.required
          }
        end)
    })
  end

  def duplicate_interaction(%Embeds.Embed{} = embed) do
    embed = Embeds.get_embed!(embed.id)

    Embeds.create_embed(%{
      title: duplicate_title(embed.title),
      content: embed.content,
      provider: embed.provider,
      enabled: false,
      position: embed.position,
      attendee_visibility: embed.attendee_visibility,
      presentation_file_id: embed.presentation_file_id
    })
  end

  def duplicate_interaction(%Quizzes.Quiz{} = quiz) do
    quiz = Quizzes.get_quiz!(quiz.id, [:quiz_questions, quiz_questions: :quiz_question_opts])

    Quizzes.create_quiz(%{
      title: duplicate_title(quiz.title),
      position: quiz.position,
      enabled: false,
      show_results: quiz.show_results,
      allow_anonymous: quiz.allow_anonymous,
      presentation_file_id: quiz.presentation_file_id,
      lti_resource_id: quiz.lti_resource_id,
      lti_line_item_url: quiz.lti_line_item_url,
      quiz_questions:
        Enum.map(quiz.quiz_questions, fn question ->
          %{
            content: question.content,
            type: question.type,
            quiz_question_opts:
              Enum.map(question.quiz_question_opts, fn opt ->
                %{
                  content: opt.content,
                  is_correct: opt.is_correct,
                  response_count: 0
                }
              end)
          }
        end)
    })
  end

  defp duplicate_title(nil), do: nil
  defp duplicate_title(title), do: "#{title} (Copy)"
end
