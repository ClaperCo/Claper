defmodule Claper.Accounts.Oidc.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          issuer: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          redirect_uri: String.t(),
          scope: String.t(),
          active: boolean(),
          response_type: String.t(),
          response_mode: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "oidc_providers" do
    field :name, :string
    field :issuer, :string
    field :client_id, :string
    field :client_secret, :string
    field :redirect_uri, :string
    field :scope, :string, default: "openid email profile"
    field :active, :boolean, default: true
    field :response_type, :string, default: "code"
    field :response_mode, :string, default: "query"

    timestamps()
  end

  @doc """
  A changeset for creating or updating an OIDC provider.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :name,
      :issuer,
      :client_id,
      :client_secret,
      :redirect_uri,
      :scope,
      :active,
      :response_type,
      :response_mode
    ])
    |> validate_required([:name, :issuer, :client_id, :client_secret, :redirect_uri])
    |> validate_format(:issuer, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_format(:redirect_uri, ~r/^https?:\/\//,
      message: "must start with http:// or https://"
    )
    |> unique_constraint(:name)
  end
end
