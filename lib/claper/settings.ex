defmodule Claper.Settings do
  @moduledoc """
  The Settings context.
  Manages global application configuration stored in the database.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Claper.Settings.GlobalConfig

  @doc """
  Gets a setting value by key.
  Returns the decrypted `encrypted_value` if present, otherwise `value`, or nil.
  """
  def get(key) when is_binary(key) do
    case Repo.get_by(GlobalConfig, key: key) do
      nil -> nil
      %GlobalConfig{encrypted_value: ev} when not is_nil(ev) -> decrypt(ev)
      %GlobalConfig{value: v} -> v
    end
  end

  @doc """
  Sets a plaintext setting value.
  Creates the record if it doesn't exist, updates if it does.
  """
  def set(key, value) when is_binary(key) do
    case Repo.get_by(GlobalConfig, key: key) do
      nil ->
        %GlobalConfig{}
        |> GlobalConfig.changeset(%{key: key, value: value, encrypted_value: nil})
        |> Repo.insert()

      config ->
        config
        |> GlobalConfig.changeset(%{value: value, encrypted_value: nil})
        |> Repo.update()
    end
  end

  @doc """
  Encrypts and stores a value in `encrypted_value`.
  Clears the plaintext `value` field.
  """
  def set_encrypted(key, value) when is_binary(key) do
    encrypted = encrypt(value)

    case Repo.get_by(GlobalConfig, key: key) do
      nil ->
        %GlobalConfig{}
        |> GlobalConfig.changeset(%{key: key, value: nil, encrypted_value: encrypted})
        |> Repo.insert()

      config ->
        config
        |> GlobalConfig.changeset(%{value: nil, encrypted_value: encrypted})
        |> Repo.update()
    end
  end

  @doc """
  Convenience: get the transcription API key (decrypted).
  """
  def get_transcription_api_key do
    get("transcription_api_key")
  end

  @doc """
  Returns true if transcription is globally enabled.
  """
  def transcription_globally_enabled? do
    get("transcription_enabled") == "true"
  end

  @doc """
  Returns true only when an administrator has explicitly enabled LTI.
  """
  def lti_enabled? do
    get("lti_enabled") == "true"
  end

  @doc """
  Clears a setting value (sets both value and encrypted_value to nil).
  """
  def clear(key) when is_binary(key) do
    case Repo.get_by(GlobalConfig, key: key) do
      nil ->
        :ok

      config ->
        config |> GlobalConfig.changeset(%{value: nil, encrypted_value: nil}) |> Repo.update()
    end
  end

  @doc """
  Seeds default settings. Inserts rows only if they don't exist.
  """
  def seed_defaults do
    defaults = [
      %{key: "transcription_enabled", value: "false"},
      %{key: "lti_enabled", value: "false"},
      %{key: "transcription_api_key"},
      %{key: "transcription_default_language", value: nil}
    ]

    Enum.each(defaults, fn attrs ->
      key = attrs.key

      unless Repo.get_by(GlobalConfig, key: key) do
        %GlobalConfig{}
        |> GlobalConfig.changeset(Map.put(attrs, :key, key))
        |> Repo.insert!()
      end
    end)
  end

  defp secret_key do
    ClaperWeb.Endpoint.config(:secret_key_base)
  end

  # Plug.Crypto tokens expire after 1 day by default; stored settings must not.
  defp encrypt(value) when is_binary(value) do
    Plug.Crypto.encrypt(secret_key(), "global_config", value, max_age: :infinity)
  end

  defp encrypt(nil), do: nil

  defp decrypt(encrypted) when is_binary(encrypted) do
    case Plug.Crypto.decrypt(secret_key(), "global_config", encrypted, max_age: :infinity) do
      {:ok, value} -> value
      {:error, _} -> nil
    end
  end

  defp decrypt(nil), do: nil
end
