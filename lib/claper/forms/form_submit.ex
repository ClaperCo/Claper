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
    |> validate_required([:form_id])
  end
end
