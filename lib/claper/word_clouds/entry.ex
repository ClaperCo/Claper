defmodule Claper.WordClouds.Entry do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          normalized_content: String.t(),
          attendee_identifier: String.t() | nil,
          word_cloud_id: integer() | nil,
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  # Attendees type free text, so without a limit the cloud would render a
  # paragraph as one word.
  @word_length 60

  schema "word_cloud_entries" do
    field :content, :string
    field :normalized_content, :string
    field :attendee_identifier, :string

    belongs_to :word_cloud, Claper.WordClouds.WordCloud
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc """
  The word as it is stored and shown: composed to NFC, surrounding whitespace
  and invisible format characters removed, cut to #{@word_length} characters,
  casing kept as typed.

  NFC makes a precomposed `ä` and an `a` followed by a combining diaeresis the
  same word, and stripping invisible characters keeps an empty-looking entry
  from passing as a word. `\\p{Cf}` is not used because it would also strip the
  tag characters that end a flag emoji.
  """
  def word(nil), do: nil

  def word(content) when is_binary(content) do
    content
    |> :unicode.characters_to_nfc_binary()
    |> String.replace(
      ~r/\A[\s\x{00AD}\x{034F}\x{180E}\x{200B}-\x{200F}\x{2060}-\x{2064}\x{FEFF}]+|[\s\x{00AD}\x{034F}\x{180E}\x{200B}-\x{200F}\x{2060}-\x{2064}\x{FEFF}]+\z/u,
      ""
    )
    |> String.slice(0, @word_length)
  end

  @doc """
  The key under which submissions of the same word are grouped.

  It is computed here and stored with the entry instead of being derived in
  SQL, because `lower()` folds case by the database collation and `btrim()`
  strips only ASCII spaces: the two would agree with `String.downcase/1` and
  `String.trim/1` on `hello` and disagree on `ÄRGER`, and the same word would
  then land in two groups.

  The browser cloud merges names by NFKC and `toLowerCase()`, so the key uses
  NFKC too and lowercases a final sigma the way the browser does in a Greek
  word. Otherwise two keys could show as one word that can only be hidden in
  part.
  """
  def normalize(nil), do: nil

  def normalize(content) when is_binary(content) do
    content
    |> word()
    |> :unicode.characters_to_nfkc_binary()
    |> String.downcase(:greek)
  end

  @doc false
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:content, :attendee_identifier, :user_id, :word_cloud_id])
    |> update_change(:content, &word/1)
    |> validate_required([:content, :word_cloud_id])
    |> put_normalized_content()
    # The cut above counts graphemes and the columns count code points, and one
    # grapheme can carry any number of combining marks.
    |> validate_length(:content, max: 255, count: :codepoints)
    |> validate_key_length()
    |> validate_user_or_attendee()
    |> unique_constraint(:content, name: :word_cloud_entries_attendee_word_index)
    |> unique_constraint(:content, name: :word_cloud_entries_user_word_index)
  end

  defp put_normalized_content(changeset) do
    case get_field(changeset, :content) do
      nil -> changeset
      content -> put_change(changeset, :normalized_content, normalize(content))
    end
  end

  # NFKC turns some single code points into as many as eighteen, so a short word
  # can have a key its column cannot hold. The attendee typed the word, not the
  # key, so the word is refused as too long.
  defp validate_key_length(changeset) do
    key = get_field(changeset, :normalized_content)

    if key && is_nil(changeset.errors[:content]) && length(String.codepoints(key)) > 255 do
      add_error(changeset, :content, "should be at most %{count} character(s)",
        count: 255,
        validation: :length,
        kind: :max,
        type: :string
      )
    else
      changeset
    end
  end

  defp validate_user_or_attendee(changeset) do
    user_id = get_field(changeset, :user_id)
    attendee_identifier = get_field(changeset, :attendee_identifier)

    if is_nil(user_id) and is_nil(attendee_identifier) do
      add_error(changeset, :user_id, "either user_id or attendee_identifier must be present")
    else
      changeset
    end
  end
end
