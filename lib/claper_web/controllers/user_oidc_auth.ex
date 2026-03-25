defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  require Logger

  defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(32)
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

    client_context = patched_client_context!()

    {:ok, redirect_uri} =
      Oidcc.Authorization.create_redirect_url(
        client_context,
        auth_opts(pkce_verifier) |> Map.merge(%{state: state, nonce: nonce})
      )

    uri = Enum.join(redirect_uri, "")

    redirect(conn, external: uri)
  end

  def callback(conn, %{"code" => code, "state" => state} = _params) do
    pkce_verifier = get_session(conn, :pkce_verifier)
    saved_state = get_session(conn, :oidc_state)
    nonce = get_session(conn, :oidc_nonce)

    if state != saved_state do
      Logger.error(
        "OIDC state mismatch: received=#{inspect(state)}, saved=#{inspect(saved_state)}"
      )

      conn
      |> clear_oidc_session()
      |> put_status(:unauthorized)
      |> put_view(ClaperWeb.ErrorView)
      |> render("csrf_error.html", %{error: "Authentication failed: state mismatch"})
    else
      client_context = patched_client_context!()

      with {:ok,
            %Oidcc.Token{
              id: %Oidcc.Token.Id{token: id_token, claims: claims},
              access: %Oidcc.Token.Access{token: access_token},
              refresh: refresh_token
            } = token} <-
             Oidcc.Token.retrieve(
               code,
               client_context,
               token_opts(pkce_verifier, nonce)
             ),
           {:ok, claims} <- maybe_enrich_claims(claims, token, client_context),
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
  defp maybe_enrich_claims(%{"email" => email} = claims, _token, _client_context)
       when is_binary(email) do
    {:ok, claims}
  end

  defp maybe_enrich_claims(claims, token, client_context) do
    case Oidcc.Userinfo.retrieve(
           token,
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

  # Build a client context with provider config overrides for broad compatibility:
  # - Disable request objects and PAR (Authelia compatibility)
  # - Ensure S256 PKCE is listed as supported (Entra ID compatibility)
  defp patched_client_context! do
    {:ok, client_context} =
      Oidcc.ClientContext.from_configuration_worker(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret()
      )

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

  defp redirect_uri do
    "#{base_url()}/users/oidc/callback"
  end

  # Options for Oidcc.Authorization.create_redirect_url/2 (uses `scopes`)
  defp auth_opts(pkce_verifier) do
    %{
      redirect_uri: redirect_uri(),
      scopes: scopes(),
      require_pkce: true,
      pkce_verifier: pkce_verifier
    }
  end

  # Options for :oidcc_token.retrieve/3 (uses `scope`)
  defp token_opts(pkce_verifier, nonce) do
    %{
      redirect_uri: redirect_uri(),
      scope: scopes(),
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
