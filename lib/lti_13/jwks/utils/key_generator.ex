defmodule Lti13.Jwks.Utils.KeyGenerator do
  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
         |> String.split("", trim: true)

  @doc """
  Create a random passphrase of size given (defaults to 256)
  """
  def passphrase(len \\ 256) do
    Enum.map(1..len, fn _i -> Enum.random(@chars) end)
    |> Enum.join("")
  end

  @doc """
  Generates RSA public and private key pair to validate between Tool and the Platform

  ## Examples
    iex> generate_key_pair()
    %{public_key: "...", private_key: "...", key_id: "..."}

  """
  def generate_key_pair do
    key_id = passphrase()

    {:ok, rsa_priv_key} = generate_key(:rsa, 4096, 65537)
    {:ok, public_key} = public_key_from_private_key(rsa_priv_key)
    {:ok, private_key_pem} = pem_entry_encode(rsa_priv_key, :RSAPrivateKey)
    {:ok, public_key_pem} = pem_entry_encode(public_key, :RSAPublicKey)

    %{public_key: public_key_pem, private_key: private_key_pem, key_id: key_id}
  end

  defp generate_key(type, bits, public_exp) do
    {:ok, :public_key.generate_key({type, bits, public_exp})}
  catch
    kind, error ->
      normalize_error(kind, error, __STACKTRACE__)
  end

  defp public_key_from_private_key(private_key) do
    public_modulus = elem(private_key, 2)
    public_exponent = elem(private_key, 3)
    {:ok, {:RSAPublicKey, public_modulus, public_exponent}}
  end

  defp pem_entry_encode(key, type) do
    pem_entry = :public_key.pem_entry_encode(type, key)
    {:ok, :public_key.pem_encode([pem_entry])}
  catch
    kind, error ->
      normalize_error(kind, error, __STACKTRACE__)
  end

  defp normalize_error(kind, error, stacktrace) do
    case Exception.normalize(kind, error) do
      %{message: message} ->
        {:error, message}

      x ->
        {kind, x, stacktrace}
    end
  end
end
