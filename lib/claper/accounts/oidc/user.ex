defmodule Claper.Accounts.Oidc.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          sub: String.t(),
          name: String.t() | nil,
          email: String.t(),
          issuer: String.t(),
          provider: String.t(),
          refresh_token: String.t(),
          access_token: String.t(),
          expires_at: NaiveDateTime.t(),
          photo_url: String.t(),
          groups: {:array, :string},
          roles: :string,
          organization: String.t(),
          user_id: integer(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "oidc_users" do
    field :sub, :string
    field :name, :string
    field :email, :string
    field :issuer, :string
    field :provider, :string
    field :id_token, :string
    field :refresh_token, :string, redact: true
    field :access_token, :string, redact: true
    field :expires_at, :naive_datetime
    field :photo_url, :string
    field :groups, {:array, :string}
    field :roles, :string
    field :organization, :string

    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :sub,
      :name,
      :email,
      :issuer,
      :provider,
      :id_token,
      :photo_url,
      :access_token,
      :expires_at,
      :groups,
      :organization,
      :user_id,
      :roles,
      :refresh_token
    ])
    |> validate_required([:sub, :email, :issuer, :provider, :id_token, :user_id])
    |> unique_constraint(:sub)
  end
end
