defmodule Lti13.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          sub: String.t(),
          name: String.t() | nil,
          email: String.t(),
          roles: [String.t()],
          user_id: integer(),
          registration_id: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "lti_13_users" do
    field :sub, :string
    field :name, :string
    field :email, :string
    field :roles, {:array, :string}

    belongs_to :user, Claper.Accounts.User
    belongs_to :registration, Lti13.Registrations.Registration

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :sub,
      :name,
      :roles,
      :email,
      :user_id,
      :registration_id
    ])
    |> validate_required([:sub, :name, :email, :roles, :user_id, :registration_id])
    |> unique_constraint(:sub)
  end
end
