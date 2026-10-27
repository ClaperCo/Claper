defmodule Lti13.LaunchStates.LaunchState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_13_launch_states" do
    field :state, :string
    field :nonce, :string
    belongs_to :registration, Lti13.Registrations.Registration
    timestamps(updated_at: false)
  end

  def changeset(launch_state, attrs) do
    launch_state
    |> cast(attrs, [:state, :nonce, :registration_id])
    |> validate_required([:state, :nonce, :registration_id])
    |> unique_constraint(:state)
    |> foreign_key_constraint(:registration_id)
  end
end
