defmodule Lti13.Registrations.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          issuer: String.t() | nil,
          client_id: String.t() | nil,
          key_set_url: String.t() | nil,
          auth_token_url: String.t() | nil,
          auth_login_url: String.t() | nil,
          auth_server: String.t() | nil,
          tool_jwk_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "lti_13_registrations" do
    field :issuer, :string
    field :client_id, :string
    field :key_set_url, :string
    field :auth_token_url, :string
    field :auth_login_url, :string
    field :auth_server, :string

    has_many :deployments, Lti13.Deployments.Deployment
    belongs_to :tool_jwk, Lti13.Jwks.Jwk, foreign_key: :tool_jwk_id

    timestamps()
  end

  @doc false
  def changeset(registration, attrs \\ %{}) do
    registration
    |> cast(attrs, [
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server,
      :tool_jwk_id
    ])
    |> validate_required([
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server,
      :tool_jwk_id
    ])
  end
end
