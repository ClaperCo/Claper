defmodule Claper.Forms.FormSubmit do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          attendee_identifier: String.t() | nil,
          response: map(),
          form_id: integer() | nil,
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "form_submits" do
    field :attendee_identifier, :string
    field :response, :map, on_replace: :delete
    belongs_to :form, Claper.Forms.Form
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(form_submit, attrs) do
    form_submit
    |> cast(attrs, [:attendee_identifier, :user_id, :form_id, :response])
    |> validate_required([:form_id, :response])
    |> validate_user_or_attendee()
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
