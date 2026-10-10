defmodule Claper.Interactions do
  alias Claper.Polls
  alias Claper.Forms
  alias Claper.Embeds
  alias Claper.Events
  alias Claper.Presentations
  alias Claper.Quizzes
  import Ecto.Query, warn: false

  @type interaction :: Polls.Poll | Forms.Form | Embeds.Embed

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

  @doc """
  Moves an interaction to another slide position.

  The interaction is disabled when moved so it doesn't stay live on a slide
  the audience is not looking at. Returns `{:ok, interaction}` (a no-op when
  the position is unchanged) or `{:error, :invalid_position}`.
  """
  def move_interaction(
        %Events.Event{
          presentation_file: %Presentations.PresentationFile{} = presentation_file
        } = event,
        interaction,
        to
      )
      when is_integer(to) do
    count = presentation_file.length || 0

    cond do
      to < 0 or to >= count -> {:error, :invalid_position}
      to == interaction.position -> {:ok, interaction}
      true -> do_move_interaction(event.uuid, interaction, to)
    end
  end

  defp do_move_interaction(event_uuid, %Polls.Poll{} = poll, to),
    do: Polls.update_poll(event_uuid, poll, %{position: to, enabled: false})

  defp do_move_interaction(event_uuid, %Forms.Form{} = form, to),
    do: Forms.update_form(event_uuid, form, %{position: to, enabled: false})

  defp do_move_interaction(event_uuid, %Embeds.Embed{} = embed, to),
    do: Embeds.update_embed(event_uuid, embed, %{position: to, enabled: false})

  # Quiz.changeset requires quiz_questions via cast_assoc, so they must be
  # loaded even though the move doesn't touch them.
  defp do_move_interaction(event_uuid, %Quizzes.Quiz{} = quiz, to) do
    quiz = Claper.Repo.preload(quiz, quiz_questions: :quiz_question_opts)
    Quizzes.update_quiz(event_uuid, quiz, %{position: to, enabled: false})
  end

  @doc """
Reorders interactions on a slide.

`ordered` is a list of `{type, id}` tuples (type being "poll", "form", "embed"
or "quiz") in their desired order. They take over the slots those interactions
currently occupy, so a partial list (e.g. one paginated page) leaves the others
in place. Order is derived from `inserted_at`, which is rewritten one second
apart starting from the slide's earliest value.

Returns `:ok` or `{:error, :invalid_interactions}` when an entry is duplicated
or doesn't belong to the slide.
"""
  def reorder_interactions(%Events.Event{} = event, position, ordered) when is_list(ordered) do
    {:ok, current} = get_interactions_at_position(event, position)
    current_keys = Enum.map(current, &interaction_key/1)

    if ordered != Enum.uniq(ordered) or not Enum.all?(ordered, &(&1 in current_keys)) do
      {:error, :invalid_interactions}
    else
      {new_order, _} =
        Enum.map_reduce(current_keys, ordered, fn key, queue ->
          if key in ordered, do: {hd(queue), tl(queue)}, else: {key, queue}
        end)

      base = current |> Enum.map(& &1.inserted_at) |> Enum.min(NaiveDateTime)

      new_order
      |> Enum.with_index()
      |> Enum.reduce(Ecto.Multi.new(), fn {{type, id} = key, index}, multi ->
        Ecto.Multi.update_all(
          multi,
          key,
          from(i in interaction_schema(type), where: i.id == ^id),
          set: [inserted_at: NaiveDateTime.add(base, index)]
        )
      end)
      |> Claper.Repo.transaction()
      |> case do
        {:ok, _} -> :ok
        {:error, _, reason, _} -> {:error, reason}
      end
    end
  end

  defp interaction_key(%Polls.Poll{id: id}), do: {"poll", id}
  defp interaction_key(%Forms.Form{id: id}), do: {"form", id}
  defp interaction_key(%Embeds.Embed{id: id}), do: {"embed", id}
  defp interaction_key(%Quizzes.Quiz{id: id}), do: {"quiz", id}

  defp interaction_schema("poll"), do: Polls.Poll
  defp interaction_schema("form"), do: Forms.Form
  defp interaction_schema("embed"), do: Embeds.Embed
  defp interaction_schema("quiz"), do: Quizzes.Quiz

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
end
