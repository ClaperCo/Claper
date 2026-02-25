defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  require Logger

  # Add PKCE-related functions
  defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp generate_pkce_challenge(verifier) do
    :crypto.hash(:sha256, verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc false
  def new(conn, _params) do
    pkce_verifier = generate_pkce_verifier()
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    conn =
      conn
      |> put_session(:pkce_verifier, pkce_verifier)
      |> put_session(:oidc_state, state)
      |> put_session(:oidc_nonce, nonce)

    {:ok, client_context} =
      Oidcc.ClientContext.from_configuration_worker(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret()
      )

    # Disable request objects and PAR for compatibility with providers
    # like Authelia that advertise support but can't validate the JWTs
    provider_config = %{client_context.provider_configuration |
      request_parameter_supported: false,
      require_signed_request_object: false,
      pushed_authorization_request_endpoint: :undefined,
      require_pushed_authorization_requests: false
    }
    client_context = %{client_context | provider_configuration: provider_config}

    {:ok, redirect_uri} =
      Oidcc.Authorization.create_redirect_url(
        client_context,
        opts(pkce_verifier) |> Map.merge(%{state: state, nonce: nonce})
      )

    uri = Enum.join(redirect_uri, "")

    redirect(conn, external: uri)
  end

  def callback(conn, %{"code" => code, "state" => state} = _params) do
    pkce_verifier = get_session(conn, :pkce_verifier)
    saved_state = get_session(conn, :oidc_state)
    nonce = get_session(conn, :oidc_nonce)

    if state != saved_state do
      Logger.error("OIDC state mismatch: received=#{inspect(state)}, saved=#{inspect(saved_state)}")

      conn
      |> clear_oidc_session()
      |> put_status(:unauthorized)
      |> put_view(ClaperWeb.ErrorView)
      |> render("csrf_error.html", %{error: "Authentication failed: state mismatch"})
    else
      token_opts =
        opts(pkce_verifier)
        |> Map.merge(%{
          nonce: nonce,
          preferred_auth_methods: [:client_secret_basic, :client_secret_post]
        })

      with {:ok,
            %Oidcc.Token{
              id: %Oidcc.Token.Id{token: id_token, claims: claims},
              access: %Oidcc.Token.Access{token: access_token},
              refresh: refresh_token
            } = token} <-
             Oidcc.retrieve_token(
               code,
               Claper.OidcProviderConfig,
               client_id(),
               client_secret(),
               token_opts
             ),
           {:ok, claims} <- maybe_enrich_claims(claims, token),
           {:ok, oidc_user} <- validate_user(id_token, access_token, refresh_token, claims) do
        conn
        |> clear_oidc_session()
        |> UserAuth.log_in_user(oidc_user.user)
      else
        {:error, reason} ->
          Logger.error("OIDC token retrieval/validation failed: #{inspect(reason)}")

          conn
          |> clear_oidc_session()
          |> put_status(:unauthorized)
          |> put_view(ClaperWeb.ErrorView)
          |> render("csrf_error.html", %{error: "Authentication failed: #{inspect(reason)}"})
      end
    end
  end

  def callback(conn, %{"code" => _code} = _params) do
    conn
    |> clear_oidc_session()
    |> put_status(:unauthorized)
    |> put_view(ClaperWeb.ErrorView)
    |> render("csrf_error.html", %{error: "Authentication failed: missing state parameter"})
  end

  def callback(conn, %{"error" => error} = _params) do
    conn
    |> clear_oidc_session()
    |> put_status(:unauthorized)
    |> put_view(ClaperWeb.ErrorView)
    |> render("csrf_error.html", %{error: "Authentication failed: #{error}"})
  end

  # Fetch userinfo to fill in claims missing from the ID token (e.g. email on Authelia)
  defp maybe_enrich_claims(%{"email" => email} = claims, _token) when is_binary(email) do
    {:ok, claims}
  end

  defp maybe_enrich_claims(claims, token) do
    case Oidcc.retrieve_userinfo(
           token,
           Claper.OidcProviderConfig,
           client_id(),
           client_secret(),
           %{preferred_auth_methods: [:client_secret_basic, :client_secret_post]}
         ) do
      {:ok, userinfo} ->
        {:ok, Map.merge(userinfo, claims)}

      {:error, reason} ->
        Logger.error("OIDC userinfo retrieval failed: #{inspect(reason)}")
        {:ok, claims}
    end
  end

  defp clear_oidc_session(conn) do
    conn
    |> delete_session(:pkce_verifier)
    |> delete_session(:oidc_state)
    |> delete_session(:oidc_nonce)
  end

  defp config do
    Application.get_env(:claper, :oidc)
  end

  defp client_id do
    config()[:client_id]
  end

  defp client_secret do
    config()[:client_secret]
  end

  defp provider_name do
    config()[:provider_name]
  end

  defp scopes do
    config()[:scopes]
  end

  defp base_url do
    Application.get_env(:claper, ClaperWeb.Endpoint)[:base_url]
  end

  defp opts(pkce_verifier) do
    url = base_url()

    base_opts = %{
      redirect_uri: "#{url}/users/oidc/callback",
      scopes: scopes(),
      require_pkce: true
    }

    if pkce_verifier do
      Map.merge(base_opts, %{
        pkce_verifier: pkce_verifier,
        code_challenge: generate_pkce_challenge(pkce_verifier),
        code_challenge_method: "S256"
      })
    else
      base_opts
    end
  end

  defp format_refresh_token(%Oidcc.Token.Refresh{token: token}) do
    token
  end

  defp format_refresh_token(:none) do
    ""
  end

  defp validate_user(id_token, access_token, refresh_token, claims) do
    mappings = config()[:property_mappings]

    case Claper.Accounts.get_or_create_user_with_oidc(%{
           sub: claims["sub"],
           issuer: claims["iss"],
           name: claims["name"],
           email: claims["email"],
           provider: provider_name(),
           expires_at: claims["exp"] |> DateTime.from_unix!() |> DateTime.to_naive(),
           id_token: id_token,
           access_token: access_token,
           refresh_token: format_refresh_token(refresh_token),
           groups: claims["groups"],
           roles: claims[mappings["roles"]],
           organization: claims[mappings["organization"]],
           photo_url: claims[mappings["photo_url"]]
         }) do
      {:error, _} ->
        {:error, %{reason: :invalid_user, msg: "Invalid user"}}

      {:ok, user} ->
        {:ok, user}
    end
  end
end
