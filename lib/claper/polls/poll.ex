defmodule Claper.Polls.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          total: integer() | nil,
          enabled: boolean() | nil,
          multiple: boolean() | nil,
          type: :choice | :word_cloud | nil,
          presentation_file_id: integer() | nil,
          poll_opts: [Claper.Polls.PollOpt.t()],
          poll_votes: [Claper.Polls.PollVote.t()] | nil,
          show_results: boolean() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "polls" do
    field :title, :string
    field :position, :integer
    field :total, :integer, virtual: true
    field :enabled, :boolean
    field :multiple, :boolean
    field :show_results, :boolean
    field :type, Ecto.Enum, values: [:choice, :word_cloud], default: :choice

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    has_many :poll_opts, Claper.Polls.PollOpt,
      preload_order: [asc: :id],
      on_replace: :delete

    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    word_cloud? = word_cloud?(poll, attrs)

    poll
    |> cast(ignore_choices_of_a_word_cloud(attrs, word_cloud?), [
      :title,
      :presentation_file_id,
      :position,
      :enabled,
      :total,
      :multiple,
      :show_results,
      :type
    ])
    |> cast_assoc(:poll_opts, required: word_cloud? == false)
    |> drop_choices_when_becoming_a_word_cloud()
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
  end

  # A word cloud's options are the words its audience typed, so nothing a form
  # submits may reach them. The form already stops rendering the inputs, but a
  # LiveView event is whatever the client sends: a hand-built "poll_opts" key
  # would otherwise be cast straight through (`required: false` means optional,
  # not ignored) and rewrite -- or delete -- the words attendees submitted.
  defp ignore_choices_of_a_word_cloud(attrs, false), do: attrs

  defp ignore_choices_of_a_word_cloud(attrs, true),
    do: Map.drop(attrs, ["poll_opts", :poll_opts])

  # A word cloud has no pre-defined choices, so the ones a poll carried while it
  # was a :choice poll go when the presenter switches an existing poll over.
  # `Claper.Polls.update_poll/3` refuses the switch outright once answers have
  # been collected, so what is dropped here is an unanswered list of choices.
  defp drop_choices_when_becoming_a_word_cloud(changeset) do
    if get_change(changeset, :type) == :word_cloud and
         Ecto.get_meta(changeset.data, :state) == :loaded do
      put_assoc(changeset, :poll_opts, [])
    else
      changeset
    end
  end

  # Word cloud polls have no pre-defined choices -- attendees type their own
  # words, which become poll_opts on the fly (see Polls.submit_word/4) --
  # so, unlike a :choice poll, an empty poll_opts list is valid here.
  defp word_cloud?(poll, attrs) do
    type =
      Map.get(attrs, "type") || Map.get(attrs, :type) || poll.type

    to_string(type) == "word_cloud"
  end
end
