defmodule Claper.RuntimeConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp_dir} do
    keys = ~w(CONFIG_DIR OIDC_CLIENT_ID OIDC_CLIENT_SECRET DISABLE_PASSWORD_LOGIN
              OIDC_TRUST_EMAIL_VERIFIED EVENT_INACTIVITY_DAYS)
    original_env = Map.new(keys, &{&1, System.get_env(&1)})

    on_exit(fn ->
      File.rm_rf!(tmp_dir)

      for {key, value} <- original_env do
        if is_nil(value), do: System.delete_env(key), else: System.put_env(key, value)
      end
    end)

    System.put_env(%{
      "CONFIG_DIR" => tmp_dir,
      "OIDC_CLIENT_ID" => "test-client",
      "OIDC_CLIENT_SECRET" => "test-secret"
    })

    System.delete_env("DISABLE_PASSWORD_LOGIN")
    System.delete_env("OIDC_TRUST_EMAIL_VERIFIED")
    System.delete_env("EVENT_INACTIVITY_DAYS")
    :ok
  end

  test "events are only terminated for inactivity once EVENT_INACTIVITY_DAYS is set" do
    assert read_claper_config()[:events][:inactivity_days] == 0

    System.put_env("EVENT_INACTIVITY_DAYS", "14")
    assert read_claper_config()[:events][:inactivity_days] == 14
  end

  test "password login stays enabled by default" do
    oidc = read_oidc_config()
    assert oidc[:enabled]
    refute oidc[:disable_password_login]
  end

  test "provider email verification is only trusted when explicitly enabled" do
    refute read_oidc_config()[:trust_email_verified]

    for {value, trusted} <- [
          {"false", false},
          {"", false},
          {"yes", false},
          {"1", false},
          {"true", true},
          {" TRUE ", true}
        ] do
      System.put_env("OIDC_TRUST_EMAIL_VERIFIED", value)
      assert read_oidc_config()[:trust_email_verified] == trusted
    end
  end

  test "password login can be disabled with configured OIDC credentials" do
    System.put_env("DISABLE_PASSWORD_LOGIN", "true")

    assert capture_io(:stderr, fn ->
             oidc = read_oidc_config()
             assert oidc[:enabled]
             assert oidc[:disable_password_login]
           end) == ""
  end

  for key <- ~w(OIDC_CLIENT_ID OIDC_CLIENT_SECRET), value <- [nil, "", " \t "] do
    test "password login stays enabled and warns with #{key}=#{inspect(value)}" do
      System.put_env("DISABLE_PASSWORD_LOGIN", "true")

      if is_nil(unquote(value)),
        do: System.delete_env(unquote(key)),
        else: System.put_env(unquote(key), unquote(value))

      warning =
        capture_io(:stderr, fn ->
          oidc = read_oidc_config()
          refute oidc[:enabled]
          refute oidc[:disable_password_login]
        end)

      assert warning =~ "DISABLE_PASSWORD_LOGIN=true has no effect"
      assert warning =~ "Password login stays enabled."
    end
  end

  test "empty secret files override environment credentials without disabling password login", %{
    tmp_dir: tmp_dir
  } do
    System.put_env("DISABLE_PASSWORD_LOGIN", "true")
    File.write!(Path.join(tmp_dir, "OIDC_CLIENT_ID"), "")
    File.write!(Path.join(tmp_dir, "OIDC_CLIENT_SECRET"), "\n")

    warning =
      capture_io(:stderr, fn ->
        oidc = read_oidc_config()
        refute oidc[:enabled]
        refute oidc[:disable_password_login]
      end)

    assert warning =~ "DISABLE_PASSWORD_LOGIN=true has no effect"
    assert warning =~ "Password login stays enabled."
  end

  defp read_oidc_config, do: read_claper_config()[:oidc]

  defp read_claper_config do
    Config.Reader.read!(Path.expand("../../config/runtime.exs", __DIR__), env: :test)[:claper]
  end
end
