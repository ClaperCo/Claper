defmodule Lti13.Nonces.Nonce do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_13_nonces" do
    field :value, :string
    field :domain, :string
    belongs_to :lti_user, Lti13.Users.User, foreign_key: :lti_user_id

    timestamps()
  end

  @doc false
  def changeset(nonce, attrs) do
    nonce
    |> cast(attrs, [:value, :domain, :lti_user_id])
    |> validate_required([:value])
    |> unique_constraint(:value, name: :value_domain_index)
  end
end
