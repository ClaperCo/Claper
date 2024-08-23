defmodule Lti13.Resources.Resource do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t() | nil,
          resource_id: integer() | nil,
          event_id: integer(),
          registration_id: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "lti_13_resources" do
    field :title, :string
    field :resource_id, :integer

    belongs_to :event, Claper.Events.Event
    belongs_to :registration, Lti13.Registrations.Registration

    timestamps()
  end

  @doc false
  def changeset(registration, attrs \\ %{}) do
    registration
    |> cast(attrs, [:title, :resource_id, :event_id, :registration_id])
    |> validate_required([:title, :resource_id, :event_id, :registration_id])
  end
end
