defmodule Claper.Polls.PollOpt do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          normalized_content: String.t() | nil,
          vote_count: integer(),
          percentage: float(),
          poll_id: integer(),
          poll: Claper.Polls.Poll.t(),
          poll_votes: [Claper.Polls.PollVote.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  # The longest word a word cloud keeps. Attendees type free text, so the cloud
  # would otherwise render a paragraph as one item.
  @word_length 60

  @derive {Jason.Encoder, only: [:content, :vote_count]}
  schema "poll_opts" do
    field :content, :string
    # Match key for word cloud submissions, set by Claper.Polls.submit_word/4 and
    # never by a form. NULL on the options a presenter typed on a choice poll.
    field :normalized_content, :string
    field :vote_count, :integer
    field :percentage, :float, virtual: true

    belongs_to :poll, Claper.Polls.Poll
    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc """
  The word a word cloud stores for what an attendee typed: the surrounding
  whitespace goes, the rest keeps the casing it was typed in.
  """
  def word(nil), do: nil

  def word(content) when is_binary(content),
    do: content |> String.trim() |> String.slice(0, @word_length)

  @doc """
  The match key two submissions of the same word share.

  This is the only definition of that rule. `Claper.Polls.submit_word/4` writes
  the key with it and the migration that introduced the column backfills the
  existing rows by calling it, rather than restating it as a SQL expression:
  `lower()` folds case by the database collation and `btrim()` only strips ASCII
  spaces, so the two would agree on `hello` and disagree on `ÄRGER`, and the
  first submission after the migration would then start a second row for a word
  the cloud already holds.
  """
  def normalize(nil), do: nil

  def normalize(content) when is_binary(content),
    do: content |> word() |> String.downcase()

  @doc false
  def changeset(poll_opt, attrs) do
    poll_opt
    |> cast(attrs, [:content, :vote_count, :poll_id])
    |> validate_required([:content])
    |> validate_length(:content, max: 255)
    |> keep_normalized_content_in_step()
    |> unique_constraint([:poll_id, :normalized_content],
      name: :poll_opts_poll_id_normalized_content_index
    )
  end

  @doc """
  Changeset for a word an attendee submitted to a word cloud: the content is the
  word as typed, and it always carries the match key derived from it.
  """
  def word_changeset(poll_opt, attrs) do
    content = word(attrs[:content])

    poll_opt
    |> changeset(%{attrs | content: content})
    |> put_change(:normalized_content, normalize(content))
  end

  # A row that carries a key is a word in a cloud, and its key is derived from
  # its content -- so whoever rewrites the content rewrites the key with it.
  # Without this a rewritten word keeps the key of the word it used to be, and
  # the next submission of the new word passes the unique index and appears in
  # the cloud a second time. A choice option has no key and gets none here.
  defp keep_normalized_content_in_step(changeset) do
    if get_field(changeset, :normalized_content) do
      put_change(changeset, :normalized_content, normalize(get_field(changeset, :content)))
    else
      changeset
    end
  end
end
