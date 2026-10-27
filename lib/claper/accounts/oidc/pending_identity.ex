defmodule Claper.Accounts.Oidc.PendingIdentity do
  @moduledoc """
  An OIDC sign-in waiting for its email address to be confirmed.

  Only hashes of the emailed token and of the initiating browser's secret are
  stored; both are required to complete the confirmation.
  """
  use Ecto.Schema

  schema "oidc_pending_identities" do
    field :token_hash, :binary, redact: true
    field :browser_hash, :binary, redact: true
    field :email, :string
    field :issuer, :string
    field :sub, :string
    field :attrs, :map, redact: true

    timestamps(updated_at: false)
  end
end
