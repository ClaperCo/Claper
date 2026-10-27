defmodule Claper.SettingsTest do
  use Claper.DataCase

  alias Claper.Repo
  alias Claper.Settings
  alias Claper.Settings.GlobalConfig

  describe "get/1 with encrypted values" do
    test "decrypts values stored more than a day ago" do
      two_days_ago = System.os_time(:second) - 2 * 86_400

      # Same shape as rows written before expiry was disabled (default 1-day max_age).
      encrypted =
        Plug.Crypto.encrypt(
          ClaperWeb.Endpoint.config(:secret_key_base),
          "global_config",
          "sk-old",
          signed_at: two_days_ago
        )

      Repo.insert!(
        %GlobalConfig{key: "transcription_api_key", encrypted_value: encrypted},
        on_conflict: {:replace, [:encrypted_value, :value]},
        conflict_target: :key
      )

      assert Settings.get_transcription_api_key() == "sk-old"
    end
  end
end
