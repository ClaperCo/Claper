defmodule Claper.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          permissions: map(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "roles" do
    field :name, :string
    field :permissions, :map, default: %{}

    has_many :users, Claper.Accounts.User

    timestamps()
  end

  @doc """
  Changeset for creating or updating a role.
  """
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
