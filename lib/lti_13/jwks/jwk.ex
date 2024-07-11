defmodule Lti13.Jwks.Jwk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_13_jwks" do
    field :pem, :string
    field :typ, :string
    field :alg, :string
    field :kid, :string
    field :active, :boolean, default: false

    has_many :registrations, Lti13.Registrations.Registration, foreign_key: :tool_jwk_id

    timestamps()
  end

  @doc false
  def changeset(jwk, attrs \\ %{}) do
    jwk
    |> cast(attrs, [:pem, :typ, :alg, :kid, :active])
    |> validate_required([:pem, :typ, :alg, :kid])
  end
end
