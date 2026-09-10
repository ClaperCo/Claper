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
          type: :choice | :slider | nil,
          min_value: integer() | nil,
          max_value: integer() | nil,
          min_label: String.t() | nil,
          max_label: String.t() | nil,
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
    field :type, Ecto.Enum, values: [:choice, :slider], default: :choice
    field :min_value, :integer, default: 1
    field :max_value, :integer, default: 10
    field :min_label, :string
    field :max_label, :string

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    has_many :poll_opts, Claper.Polls.PollOpt,
      preload_order: [asc: :id],
      on_replace: :delete

    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [
      :title,
      :presentation_file_id,
      :position,
      :enabled,
      :total,
      :multiple,
      :show_results,
      :type,
      :min_value,
      :max_value,
      :min_label,
      :max_label
    ])
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
    |> validate_length(:min_label, max: 60)
    |> validate_length(:max_label, max: 60)
    |> validate_range()
    |> cast_opts_for_type()
  end

  # Slider polls have no pre-defined choices -- attendees pick a value on a
  # scale, and every distinct value becomes a poll_opt on the fly (see
  # Polls.submit_rating/4) -- so, unlike a :choice poll, an empty poll_opts
  # list is valid here. Several answers make no sense on a scale either: an
  # attendee submits one rating.
  defp cast_opts_for_type(changeset) do
    case get_field(changeset, :type) do
      :slider ->
        changeset
        |> put_change(:multiple, false)
        |> cast_assoc(:poll_opts, required: false)

      _choice ->
        cast_assoc(changeset, :poll_opts, required: true)
    end
  end

  # The range belongs to every poll, not only to the slider that shows it: the
  # columns are filled for both types, and a rating is only ever accepted inside
  # this range, so a poll whose range is impossible must not be saved at all.
  defp validate_range(changeset) do
    changeset
    |> validate_required([:min_value, :max_value])
    |> validate_number(:min_value, greater_than_or_equal_to: 0, less_than_or_equal_to: 99)
    |> validate_number(:max_value, greater_than_or_equal_to: 1, less_than_or_equal_to: 100)
    |> validate_highest_above_lowest()
    |> check_constraint(:max_value,
      name: :polls_value_range,
      message: "must be greater than the lowest value"
    )
  end

  defp validate_highest_above_lowest(changeset) do
    min = get_field(changeset, :min_value)
    max = get_field(changeset, :max_value)

    if is_integer(min) && is_integer(max) && max <= min do
      add_error(changeset, :max_value, "must be greater than the lowest value")
    else
      changeset
    end
  end
end
