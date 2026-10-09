defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.

    A provider is addressed by its slug, so an instance can offer several of them
    at once: `/users/auth/google`, `/users/auth/entra`, and so on. The legacy
    `/users/oidc` routes keep working and use the provider described by the
    `OIDC_*` environment variables, under the `default` slug.
  """
  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider
  alias Claper.Accounts.Oidc.WorkerSupervisor
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  require Logger

  @legacy_slug "default"
  @session_slug :oidc_provider_slug

  defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc false
  def new(conn, params) do
    case fetch_provider(conn, params) do
      {:ok, provider} ->
        with {:ok, client_context} <- client_context(provider) do
          pkce_verifier = generate_pkce_verifier()
          state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
          nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

          conn =
            conn
            |> put_session(:pkce_verifier, pkce_verifier)
            |> put_session(:oidc_state, state)
            |> put_session(:oidc_nonce, nonce)
            |> put_session(@session_slug, provider.slug)

          {:ok, redirect_uri} =
            Oidcc.Authorization.create_redirect_url(
              client_context,
              auth_opts(provider, pkce_verifier) |> Map.merge(%{state: state, nonce: nonce})
            )

          redirect(conn, external: Enum.join(redirect_uri, ""))
        else
          {:error, reason} ->
            fail(conn, :service_unavailable, provider_unavailable(provider, reason))
        end

      {:error, reason} ->
        fail(conn, :bad_request, reason)
    end
  end

  @doc false
  def callback(conn, %{"code" => code, "state" => state} = params) do
    with {:ok, provider} <- fetch_provider(conn, params),
         :ok <- check_provider_session(conn, provider),
         :ok <- check_state(conn, state),
         {:ok, token} <- retrieve_token(conn, provider, code),
         {:ok, claims} <- maybe_enrich_claims(token.claims, token, provider),
         {:ok, oidc_user} <- validate_user(provider, token, claims) do
      conn
      |> clear_oidc_session()
      |> UserAuth.log_in_user(oidc_user.user)
    else
      {:error, reason} ->
        Logger.error("OIDC authentication failed: #{inspect(reason)}")

        conn
        |> clear_oidc_session()
        |> fail(:unauthorized, reason)
    end
  end

  def callback(conn, %{"code" => _code} = _params) do
    conn
    |> clear_oidc_session()
    |> fail(:unauthorized, "missing state parameter")
  end

  def callback(conn, %{"error" => error} = _params) do
    conn
    |> clear_oidc_session()
    |> fail(:unauthorized, error)
  end

  # Resolves the provider named in the URL, or the one configured through the
  # environment when the request comes from the legacy route.
  defp fetch_provider(_conn, %{"provider" => @legacy_slug}), do: legacy_provider()

  defp fetch_provider(_conn, %{"provider" => slug}) when is_binary(slug),
    do: database_provider(slug)

  defp fetch_provider(_conn, _params), do: legacy_provider()

  defp database_provider(slug) do
    {:ok, Oidc.get_active_provider_by_slug!(slug)}
  rescue
    Ecto.NoResultsError -> {:error, "unknown or disabled provider: #{slug}"}
  end

  defp legacy_provider do
    config = config()

    if config[:enabled] do
      {:ok,
       %{
         slug: @legacy_slug,
         name: config[:provider_name],
         issuer: config[:issuer],
         client_id: config[:client_id],
         client_secret: config[:client_secret],
         scopes: config[:scopes],
         redirect_uri: "#{base_url()}/users/oidc/callback",
         property_mappings: config[:property_mappings]
       }}
    else
      {:error, "no OIDC provider is configured"}
    end
  end

  defp provider_scopes(%Provider{scope: scope}), do: String.split(scope || "", " ", trim: true)
  defp provider_scopes(%{scopes: scopes}), do: scopes

  # Property mappings stay a global setting: the claim names of an IdP are an
  # instance-wide convention, not a per-provider one.
  defp provider_mappings(%Provider{}), do: config()[:property_mappings]
  defp provider_mappings(%{property_mappings: mappings}), do: mappings

  # A stored provider carries the redirect URI its admin registered. A blank one
  # falls back to the route of that provider.
  defp provider_redirect_uri(%Provider{slug: slug, redirect_uri: redirect_uri}) do
    case redirect_uri do
      value when is_binary(value) and value != "" -> value
      _ -> "#{base_url()}/users/auth/#{slug}/callback"
    end
  end

  defp provider_redirect_uri(%{redirect_uri: redirect_uri}), do: redirect_uri

  defp provider_name(%Provider{name: name}), do: name
  defp provider_name(%{name: name}), do: name

  defp check_provider_session(conn, provider) do
    case get_session(conn, @session_slug) do
      nil -> :ok
      slug when slug == provider.slug -> :ok
      other -> {:error, "authorization was started for provider #{other}, not #{provider.slug}"}
    end
  end

  defp check_state(conn, state) do
    case get_session(conn, :oidc_state) do
      ^state -> :ok
      saved -> {:error, "state mismatch: received #{state}, saved #{inspect(saved)}"}
    end
  end

  defp retrieve_token(conn, provider, code) do
    pkce_verifier = get_session(conn, :pkce_verifier)
    nonce = get_session(conn, :oidc_nonce)

    with {:ok, client_context} <- client_context(provider) do
      case Oidcc.Token.retrieve(code, client_context, token_opts(provider, pkce_verifier, nonce)) do
        {:ok,
         %Oidcc.Token{
           id: %Oidcc.Token.Id{token: id_token, claims: claims},
           access: %Oidcc.Token.Access{token: access_token},
           refresh: refresh
         } = token} ->
          {:ok,
           %{
             token: token,
             id_token: id_token,
             access_token: access_token,
             refresh_token: format_refresh_token(refresh),
             claims: claims
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Fetch userinfo to fill in claims missing from the ID token (e.g. email on Authelia)
  defp maybe_enrich_claims(%{"email" => email} = claims, _token, _provider)
       when is_binary(email) do
    {:ok, claims}
  end

  defp maybe_enrich_claims(claims, token, provider) do
    with {:ok, client_context} <- client_context(provider) do
      case Oidcc.Userinfo.retrieve(
             token.token,
             client_context,
             %{preferred_auth_methods: [:client_secret_basic, :client_secret_post]}
           ) do
        {:ok, userinfo} ->
          {:ok, Map.merge(userinfo, claims)}

        {:error, reason} ->
          Logger.error("OIDC userinfo retrieval failed: #{inspect(reason)}")
          {:ok, claims}
      end
    end
  end

  # Builds a client context for a provider. The configuration worker fetches its
  # discovery document asynchronously, so a request that arrives just after the
  # provider was enabled, or just after boot, can find it not ready yet; wait
  # briefly for it instead of failing the login outright.
  @context_attempts 10
  @context_delay_ms 200

  defp client_context(provider), do: client_context(provider, @context_attempts)

  defp client_context(provider, attempts) do
    case Oidcc.ClientContext.from_configuration_worker(
           WorkerSupervisor.worker_name(provider.slug),
           provider.client_id,
           provider.client_secret
         ) do
      {:ok, client_context} ->
        {:ok, patch_provider_configuration(client_context)}

      {:error, :provider_not_ready} when attempts > 1 ->
        Process.sleep(@context_delay_ms)
        client_context(provider, attempts - 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Provider config overrides for broad compatibility:
  # - Disable request objects and PAR (Authelia compatibility)
  # - Ensure S256 PKCE is listed as supported (Entra ID compatibility)
  defp patch_provider_configuration(client_context) do
    provider_config = %{
      client_context.provider_configuration
      | request_parameter_supported: false,
        require_signed_request_object: false,
        pushed_authorization_request_endpoint: :undefined,
        require_pushed_authorization_requests: false,
        code_challenge_methods_supported: ["S256"]
    }

    %{client_context | provider_configuration: provider_config}
  end

  defp provider_unavailable(provider, reason) do
    "the provider #{provider.slug} is not available right now (#{inspect(reason)})"
  end

  defp clear_oidc_session(conn) do
    conn
    |> delete_session(:pkce_verifier)
    |> delete_session(:oidc_state)
    |> delete_session(:oidc_nonce)
    |> delete_session(@session_slug)
  end

  defp fail(conn, status, message) do
    conn
    |> put_status(status)
    |> put_view(ClaperWeb.ErrorView)
    |> render("csrf_error.html", %{error: "Authentication failed: #{to_string(message)}"})
  end

  defp config do
    Application.get_env(:claper, :oidc)
  end

  defp base_url do
    Application.get_env(:claper, ClaperWeb.Endpoint)[:base_url]
  end

  # Options for Oidcc.Authorization.create_redirect_url/2 (uses `scopes`)
  defp auth_opts(provider, pkce_verifier) do
    %{
      redirect_uri: provider_redirect_uri(provider),
      scopes: provider_scopes(provider),
      require_pkce: true,
      pkce_verifier: pkce_verifier
    }
  end

  # Options for :oidcc_token.retrieve/3 (uses `scope`)
  defp token_opts(provider, pkce_verifier, nonce) do
    %{
      redirect_uri: provider_redirect_uri(provider),
      scope: provider_scopes(provider),
      require_pkce: true,
      pkce_verifier: pkce_verifier,
      nonce: nonce,
      preferred_auth_methods: [:client_secret_basic, :client_secret_post]
    }
  end

  defp format_refresh_token(%Oidcc.Token.Refresh{token: token}) do
    token
  end

  defp format_refresh_token(:none) do
    ""
  end

  defp validate_user(provider, token, claims) do
    mappings = provider_mappings(provider) || %{}

    case Claper.Accounts.get_or_create_user_with_oidc(%{
           sub: claims["sub"],
           issuer: claims["iss"],
           name: claims["name"],
           first_name: claims["given_name"],
           last_name: claims["family_name"],
           email: claims["email"],
           provider: provider_name(provider),
           expires_at: claims["exp"] |> DateTime.from_unix!() |> DateTime.to_naive(),
           id_token: token.id_token,
           access_token: token.access_token,
           refresh_token: token.refresh_token,
           groups: claims["groups"],
           roles: claims[mappings["roles"]],
           organization: claims[mappings["organization"]],
           photo_url: claims[mappings["photo_url"]]
         }) do
      {:error, _} ->
        {:error, :invalid_user}

      {:ok, user} ->
        {:ok, user}
    end
  end
end
