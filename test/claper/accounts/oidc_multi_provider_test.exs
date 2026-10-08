defmodule Claper.Accounts.OidcMultiProviderTest do
  use Claper.DataCase, async: false

  alias Claper.Accounts.Oidc

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

  test "the slug is derived from the display name" do
    assert {:ok, provider} = Oidc.create_provider(provider_attrs(%{name: "Microsoft Entra ID"}))
    assert provider.slug == "microsoft-entra-id"
  end

  test "an explicit slug is kept" do
    assert {:ok, provider} = Oidc.create_provider(provider_attrs(%{slug: "corp-sso"}))
    assert provider.slug == "corp-sso"
  end

  test "a duplicated slug is reported as a changeset error, not as a database error" do
    assert {:ok, _provider} = Oidc.create_provider(provider_attrs())

    assert {:error, changeset} =
             Oidc.create_provider(provider_attrs(%{issuer: "https://other.example"}))

    assert [{"has already been taken", _}] = changeset.errors[:slug]
  end

  test "a duplicated issuer is reported as a changeset error" do
    assert {:ok, _provider} = Oidc.create_provider(provider_attrs())

    assert {:error, changeset} =
             Oidc.create_provider(provider_attrs(%{name: "Same issuer"}))

    assert [{"has already been taken", _}] = changeset.errors[:issuer]
  end

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

  test "password login stays available while no provider is configured" do
    refute Oidc.any_provider_enabled?()
    refute Oidc.password_login_disabled?()
  end

  test "an external identity is matched on the issuer and the subject together" do
    {:ok, first} = Oidc.create_provider(provider_attrs(%{name: "First", issuer: "https://a.example"}))

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
