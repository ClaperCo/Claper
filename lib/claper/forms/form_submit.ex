defmodule Claper.Forms.FormSubmit do
  use Ecto.Schema
  import Ecto.Changeset

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
