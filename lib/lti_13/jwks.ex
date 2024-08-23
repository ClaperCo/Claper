defmodule Lti13.Jwks do
  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Lti13.Jwks.Jwk

  def create_jwk(attrs) do
    %Jwk{}
    |> Jwk.changeset(attrs)
    |> Repo.insert()
  end

  def get_active_jwk() do
    case Repo.all(from(k in Jwk, where: k.active == true, order_by: [desc: k.id], limit: 1)) do
      [head | _] -> head
      _ -> {:error, %{msg: "No active Jwk found", reason: :not_found}}
    end
  end

  def get_all_jwks() do
    Repo.all(from(k in Jwk))
  end

  def get_jwk_by_registration(%Lti13.Registrations.Registration{tool_jwk_id: tool_jwk_id}) do
    Repo.one(
      from(jwk in Jwk,
        where: jwk.id == ^tool_jwk_id
      )
    )
  end

  @doc """
  Gets a all public keys.
  ## Examples
      iex> get_all_public_keys()
      %{keys: []}
  """
  def get_all_public_keys() do
    public_keys =
      get_all_jwks()
      |> Enum.map(fn %{pem: pem, typ: typ, alg: alg, kid: kid} ->
        pem
        |> JOSE.JWK.from_pem()
        |> JOSE.JWK.to_public()
        |> JOSE.JWK.to_map()
        |> (fn {_kty, public_jwk} -> public_jwk end).()
        |> Map.put("typ", typ)
        |> Map.put("alg", alg)
        |> Map.put("kid", kid)
        |> Map.put("use", "sig")
      end)

    %{keys: public_keys}
  end
end
