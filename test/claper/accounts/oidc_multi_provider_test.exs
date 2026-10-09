defmodule Claper.Accounts.OidcMultiProviderTest do
  use Claper.DataCase, async: false

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider
  alias Claper.Accounts.Oidc.ProviderLoader
  alias Claper.Accounts.Oidc.WorkerSupervisor

  defp provider_attrs(attrs \\ %{}) do
    Map.merge(
      %{
        name: "Google",
        issuer: "https://issuer.example",
        client_id: "client-id",
        client_secret: "client-secret",
        redirect_uri: "http://localhost:4000/users/auth/google/callback"
      },
      attrs
    )
  end

  describe "provider slug" do
    test "the slug is derived from the display name" do
      assert {:ok, provider} = Oidc.create_provider(provider_attrs(%{name: "Microsoft Entra ID"}))
      assert provider.slug == "microsoft-entra-id"
    end

    test "an explicit slug is kept" do
      assert {:ok, provider} = Oidc.create_provider(provider_attrs(%{slug: "corp-sso"}))
      assert provider.slug == "corp-sso"
    end

    test "a blank explicit slug falls back to the name" do
      assert {:ok, provider} = Oidc.create_provider(provider_attrs(%{slug: ""}))
      assert provider.slug == "google"
    end

    test "a slug that is not URL-safe is refused" do
      assert {:error, changeset} = Oidc.create_provider(provider_attrs(%{slug: "Corp SSO"}))

      assert {"must contain lowercase letters, digits and single hyphens", _} =
               changeset.errors[:slug]
    end

    test "a duplicated slug is reported as a changeset error, not as a database error" do
      assert {:ok, _provider} = Oidc.create_provider(provider_attrs())

      assert {:error, changeset} =
               Oidc.create_provider(provider_attrs(%{issuer: "https://other.example"}))

      assert {"has already been taken", _} = changeset.errors[:slug]
    end

    test "a duplicated issuer is reported as a changeset error" do
      assert {:ok, _provider} = Oidc.create_provider(provider_attrs())

      assert {:error, changeset} =
               Oidc.create_provider(provider_attrs(%{name: "Same issuer"}))

      assert {"has already been taken", _} = changeset.errors[:issuer]
    end
  end

  describe "listing and lookup" do
    test "list_active_providers orders by position and leaves disabled providers out" do
      {:ok, second} =
        Oidc.create_provider(
          provider_attrs(%{name: "Second", issuer: "https://second.example", position: 2})
        )

      {:ok, first} =
        Oidc.create_provider(
          provider_attrs(%{name: "First", issuer: "https://first.example", position: 1})
        )

      {:ok, _disabled} =
        Oidc.create_provider(
          provider_attrs(%{name: "Disabled", issuer: "https://off.example", active: false})
        )

      assert Enum.map(Oidc.list_active_providers(), & &1.slug) == [first.slug, second.slug]
    end

    test "get_active_provider_by_slug!/1 refuses a disabled provider" do
      {:ok, provider} = Oidc.create_provider(provider_attrs(%{active: false}))

      assert_raise Ecto.NoResultsError, fn ->
        Oidc.get_active_provider_by_slug!(provider.slug)
      end
    end
  end

  describe "password login" do
    test "stays available while no provider is configured" do
      refute Oidc.any_provider_enabled?()
      refute Oidc.password_login_disabled?()
    end

    test "is only disabled when a provider is reachable" do
      original = Application.get_env(:claper, :oidc)
      on_exit(fn -> Application.put_env(:claper, :oidc, original) end)

      Application.put_env(
        :claper,
        :oidc,
        Keyword.put(original, :disable_password_login_requested, true)
      )

      refute Oidc.password_login_disabled?()

      {:ok, _provider} = Oidc.create_provider(provider_attrs())

      assert Oidc.any_provider_enabled?()
      assert Oidc.password_login_disabled?()
    end
  end

  describe "worker supervision" do
    test "a worker is named by its slug in the registry" do
      assert WorkerSupervisor.worker_name("google") ==
               {:via, Registry, {Claper.OidcRegistry, "google"}}

      assert WorkerSupervisor.worker_name(%Provider{slug: "corp"}) ==
               {:via, Registry, {Claper.OidcRegistry, "corp"}}
    end

    test "whereis/1 returns nil when no worker runs" do
      assert WorkerSupervisor.whereis("nope") == nil
    end

    test "the legacy provider is not started when a stored provider serves the same issuer" do
      {:ok, _provider} = Oidc.create_provider(provider_attrs(%{issuer: "https://corp.example"}))

      assert :ok = WorkerSupervisor.start_legacy_provider("https://corp.example")
      assert WorkerSupervisor.whereis("default") == nil
    end

    test "stop_all/0 is a no-op when nothing runs" do
      assert :ok = WorkerSupervisor.stop_all()
    end
  end

  describe "provider loader" do
    test "reload/0 stays up when no provider is configured" do
      assert :ok = ProviderLoader.reload()
    end
  end

  describe "external identity" do
    test "is matched on the issuer and the subject together" do
      {:ok, first} =
        Oidc.create_provider(provider_attrs(%{name: "First", issuer: "https://a.example"}))

      {:ok, second} =
        Oidc.create_provider(provider_attrs(%{name: "Second", issuer: "https://b.example"}))

      attrs = fn provider ->
        %{
          sub: "12345",
          issuer: provider.issuer,
          email: "someone@example.com",
          name: "Someone",
          provider: provider.name,
          id_token: "id-token",
          expires_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        }
      end

      assert {:ok, first_identity} = Claper.Accounts.get_or_create_user_with_oidc(attrs.(first))
      assert {:ok, second_identity} = Claper.Accounts.get_or_create_user_with_oidc(attrs.(second))

      # Two providers minted the same subject, and they stay two distinct
      # identities, each reachable through its own issuer.
      refute first_identity.id == second_identity.id
      assert Claper.Accounts.get_oidc_user(first.issuer, "12345").id == first_identity.id
      assert Claper.Accounts.get_oidc_user(second.issuer, "12345").id == second_identity.id
    end
  end
end
