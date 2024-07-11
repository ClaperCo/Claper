defmodule Lti13.Nonces do
  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Lti13.Nonces.Nonce

  def get_nonce(value, domain \\ nil) do
    case domain do
      nil ->
        Repo.get_by(Nonce, value: value)

      domain ->
        Repo.get_by(Nonce, value: value, domain: domain)
    end
  end

  def create_nonce(attrs) do
    %Nonce{}
    |> Nonce.changeset(attrs)
    |> Repo.insert()
  end

  # 86400 seconds = 24 hours
  def delete_expired_nonces(nonce_ttl_sec \\ 86_4000) do
    nonce_expiry = DateTime.utc_now() |> DateTime.add(-nonce_ttl_sec, :second)
    Repo.delete_all(from(n in Nonce, where: n.inserted_at < ^nonce_expiry))
  end
end
