defmodule Claper.Scales.Scale do
  use Ecto.Schema
  import Ecto.Changeset
  use Gettext, backend: ClaperWeb.Gettext

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          min_value: integer(),
          max_value: integer(),
          step: integer(),
          min_label: String.t() | nil,
          max_label: String.t() | nil,
          position: integer() | nil,
          enabled: boolean(),
          show_results: boolean(),
          presentation_file_id: integer() | nil,
          responses: [Claper.Scales.ScaleResponse.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  # Every point of the scale is drawn as a bar in the results.
  @max_points 101
  @value_limit 1_000_000
  @range_fields [:min_value, :max_value, :step]

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "scales" do
    field :title, :string
    field :min_value, :integer, default: 1
    field :max_value, :integer, default: 10
    field :step, :integer, default: 1
    field :min_label, :string
    field :max_label, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :show_results, :boolean, default: true

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :responses, Claper.Scales.ScaleResponse

    timestamps()
  end

  @doc """
  Builds a changeset for a scale.

  Pass `answered: true` when the scale already has responses: its range is then
  locked, because a stored value would otherwise fall off the scale or change
  its meaning.
  """
  def changeset(scale, attrs \\ %{}, opts \\ []) do
    scale
    |> cast(attrs, [
      :title,
      :min_value,
      :max_value,
      :step,
      :min_label,
      :max_label,
      :position,
      :enabled,
      :show_results,
      :presentation_file_id
    ])
    |> validate_required([:title, :presentation_file_id, :position | @range_fields])
    |> validate_length(:title, max: 255, count: :codepoints)
    |> validate_length(:min_label, max: 60, count: :codepoints)
    |> validate_length(:max_label, max: 60, count: :codepoints)
    |> validate_number(:min_value,
      greater_than_or_equal_to: -@value_limit,
      less_than_or_equal_to: @value_limit
    )
    |> validate_number(:max_value,
      greater_than_or_equal_to: -@value_limit,
      less_than_or_equal_to: @value_limit
    )
    |> validate_number(:step, greater_than: 0)
    |> validate_range()
    |> check_constraint(:max_value, name: :min_below_max)
    |> check_constraint(:step, name: :step_positive)
    |> validate_range_locked(Keyword.get(opts, :answered, false))
  end

  defp validate_range(changeset) do
    min = get_field(changeset, :min_value)
    max = get_field(changeset, :max_value)
    step = get_field(changeset, :step)

    cond do
      Enum.any?(@range_fields, &Keyword.has_key?(changeset.errors, &1)) ->
        changeset

      max <= min ->
        add_error(changeset, :max_value, gettext("must be greater than the lowest value"))

      rem(max - min, step) != 0 ->
        add_error(changeset, :step, gettext("must divide the range evenly"))

      div(max - min, step) + 1 > @max_points ->
        add_error(
          changeset,
          :step,
          gettext("is too small, a slider can have at most %{count} values", count: @max_points)
        )

      true ->
        changeset
    end
  end

  defp validate_range_locked(changeset, false), do: changeset

  defp validate_range_locked(changeset, true) do
    Enum.reduce(@range_fields, changeset, fn field, changeset ->
      if Map.has_key?(changeset.changes, field) do
        add_error(changeset, field, gettext("cannot be changed once attendees have answered"))
      else
        changeset
      end
    end)
  end

  @doc """
  Returns every value an attendee can pick, lowest first.
  """
  def points(%__MODULE__{min_value: min, max_value: max, step: step}),
    do: Enum.to_list(min..max//step)

  @doc """
  Returns the value the slider starts at: the point in the middle of the scale,
  or the lower of the two middle points.
  """
  def middle(%__MODULE__{min_value: min, max_value: max, step: step}),
    do: min + div(div(max - min, step), 2) * step
end
