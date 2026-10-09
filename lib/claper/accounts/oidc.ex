defmodule Claper.Accounts.Oidc do
  @moduledoc """
  The OIDC context for authentication and provider management.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Claper.Accounts.Oidc.Provider

  @doc """
  Returns the list of oidc_providers.

  ## Examples

      iex> list_providers()
      [%Provider{}, ...]

  """
  def list_providers do
    Repo.all(Provider)
  end

  @doc """
  Returns the enabled providers, in the order they should appear on the login page.

  ## Examples

      iex> list_active_providers()
      [%Provider{}, ...]

  """
  def list_active_providers do
    from(p in Provider,
      where: p.active == true,
      order_by: [asc: p.position, asc: p.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single enabled provider by its slug.

  Raises `Ecto.NoResultsError` if no enabled provider carries that slug.

  ## Examples

      iex> get_active_provider_by_slug!("google")
      %Provider{}

      iex> get_active_provider_by_slug!("nope")
      ** (Ecto.NoResultsError)

  """
  def get_active_provider_by_slug!(slug) when is_binary(slug) do
    Repo.one!(
      from p in Provider,
        where: p.slug == ^slug and p.active == true
    )
  end

  @doc """
  Returns true when at least one provider can be used to log in, either from the
  database or from the legacy environment configuration.
  """
  def any_provider_enabled? do
    list_active_providers() != [] or Application.get_env(:claper, :oidc)[:enabled] == true
  end

  @doc """
  Gets a single provider.

  Raises `Ecto.NoResultsError` if the Provider does not exist.

  ## Examples

      iex> get_provider!(123)
      %Provider{}

      iex> get_provider!(456)
      ** (Ecto.NoResultsError)

  """
  def get_provider!(id), do: Repo.get!(Provider, id)

  @doc """
  Gets the provider carrying a display name, or nil.

  ## Examples

      iex> get_provider_by_name("Google")
      %Provider{}

  """
  def get_provider_by_name(name) when is_binary(name) do
    Repo.get_by(Provider, name: name)
  end

  @doc """
  Creates a provider.

  ## Examples

      iex> create_provider(%{field: value})
      {:ok, %Provider{}}

      iex> create_provider(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_provider(attrs \\ %{}) do
    %Provider{}
    |> Provider.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a provider.

  ## Examples

      iex> update_provider(provider, %{field: new_value})
      {:ok, %Provider{}}

      iex> update_provider(provider, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_provider(%Provider{} = provider, attrs) do
    provider
    |> Provider.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a provider.

  ## Examples

      iex> delete_provider(provider)
      {:ok, %Provider{}}

      iex> delete_provider(provider)
      {:error, %Ecto.Changeset{}}

  """
  def delete_provider(%Provider{} = provider) do
    Repo.delete(provider)
  end

  @doc """
  True when the administrator asked for password login to be disabled and at
  least one provider is available to log in with, from the database or from the
  environment.

  `DISABLE_PASSWORD_LOGIN` alone is not enough: with no provider reachable,
  nobody, including the seeded default admin, could log in.
  """
  def password_login_disabled? do
    requested?() and any_provider_enabled?()
  end

  defp requested? do
    Application.get_env(:claper, :oidc)[:disable_password_login_requested] == true
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking provider changes.

  ## Examples

      iex> change_provider(provider)
      %Ecto.Changeset{data: %Provider{}}

  """
  def change_provider(%Provider{} = provider, attrs \\ %{}) do
    Provider.changeset(provider, attrs)
  end

  @doc """
  Search providers by name or issuer.

  ## Examples

      iex> search_providers("%example%")
      [%Provider{}, ...]

  """
  def search_providers(search_term) do
    from(p in Provider,
      where: ilike(p.name, ^search_term) or ilike(p.issuer, ^search_term)
    )
    |> Repo.all()
  end
end
