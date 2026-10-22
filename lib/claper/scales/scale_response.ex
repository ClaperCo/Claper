defmodule Claper.Scales.ScaleResponse do
  use Ecto.Schema
  import Ecto.Changeset

  alias Claper.Scales.Scale

  @type t :: %__MODULE__{
          id: integer(),
          value: integer(),
          attendee_identifier: String.t() | nil,
          scale_id: integer() | nil,
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "scale_responses" do
    field :value, :integer
    field :attendee_identifier, :string

    belongs_to :scale, Scale
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc """
  Builds a changeset for a response to `scale`. The value has to be one of the
  scale's points.
  """
  def changeset(response, attrs, %Scale{} = scale) do
    response
    |> cast(attrs, [:value, :attendee_identifier, :user_id])
    |> put_change(:scale_id, scale.id)
    |> validate_required([:value, :scale_id])
    |> validate_number(:value,
      greater_than_or_equal_to: scale.min_value,
      less_than_or_equal_to: scale.max_value
    )
    |> validate_step(scale)
    |> validate_respondent()
    |> check_constraint(:user_id, name: :one_respondent)
    |> unique_constraint(:scale_id, name: :scale_responses_attendee_index)
    |> unique_constraint(:scale_id, name: :scale_responses_user_index)
  end

  defp validate_step(changeset, scale) do
    validate_change(changeset, :value, fn :value, value ->
      if rem(value - scale.min_value, scale.step) == 0,
        do: [],
        else: [value: "is not a point on the scale"]
    end)
  end

  defp validate_respondent(changeset) do
    case {get_field(changeset, :user_id), get_field(changeset, :attendee_identifier)} do
      {nil, nil} ->
        add_error(changeset, :user_id, "either user_id or attendee_identifier must be present")

      {user_id, attendee_identifier}
      when not is_nil(user_id) and not is_nil(attendee_identifier) ->
        add_error(changeset, :user_id, "only one of user_id or attendee_identifier may be set")

      _ ->
        changeset
    end
  end
end
