defmodule Claper.Stats.Stat do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          attendee_identifier: String.t() | nil,
          event_id: integer() | nil,
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "stats" do
    field :attendee_identifier, :string

    belongs_to :event, Claper.Events.Event
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [
      :attendee_identifier,
      :event_id,
      :user_id
    ])
    |> cast_assoc(:event)
    |> unique_constraint([:event_id, :user_id])
    |> unique_constraint([:event_id, :attendee_identifier])
  end
end
