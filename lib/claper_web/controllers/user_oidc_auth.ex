defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  defp generate_pkce_challenge(code_verifier) do
    :crypto.hash(:sha256, code_verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc false
  def new(conn, _params) do
   pkce_verifier = generate_pkce_verifier()
    pkce_challenge = generate_pkce_challenge(pkce_verifier)
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    nonce = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

    conn =
      conn
      |> put_session(:pkce_verifier, pkce_verifier)
      |> put_session(:oidc_state, state)
      |> put_session(:oidc_nonce, nonce)

  @doc false
  def new(conn, _params) do
    {:ok, redirect_uri} =
      Oidcc.create_redirect_url(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret(),
        opts(pkce_challenge, state, nonce) # Pass code_challenge, state, and nonce
      )

    uri = Enum.join(redirect_uri, "")
    redirect(conn, external: uri)

  end

    def callback(conn, %{"code" => code, "state" => returned_state} = _params) do
    pkce_verifier = get_session(conn, :pkce_verifier)
    expected_state = get_session(conn, :oidc_state)
    expected_nonce = get_session(conn, :oidc_nonce)

    if returned_state != expected_state do
      conn
      |> put_status(:unauthorized)
      |> put_view(ClaperWeb.ErrorView)
      |> render("csrf_error.html", %{error: "Invalid state parameter"})
    else
      with {:ok,
            %Oidcc.Token{
              id: %Oidcc.Token.Id{token: id_token, claims: claims},
              access: %Oidcc.Token.Access{token: access_token},
              refresh: refresh_token
            }} <-
             Oidcc.retrieve_token(
               code,
               Claper.OidcProviderConfig,
               client_id(),
               client_secret(),
               opts(pkce_verifier, nil, expected_nonce) # Pass code_verifier and nonce
             ),
           {:ok, oidc_user} <- validate_user(id_token, access_token, refresh_token, claims, expected_nonce) do
        conn
        |> configure_session(renew: true)
        |> delete_session(:pkce_verifier)
        |> delete_session(:oidc_state)
        |> delete_session(:oidc_nonce)
        |> UserAuth.log_in_user(oidc_user.user)
      else
        {:error, reason} ->
          conn
          |> put_status(:unauthorized)
          |> put_view(ClaperWeb.ErrorView)
          |> render("csrf_error.html", %{error: "Authentication failed: #{inspect(reason)}"})
      end
        opts()
      )

    uri = Enum.join(redirect_uri, "")

    redirect(conn, external: uri)
  end

  def callback(conn, %{"code" => code} = _params) do
    with {:ok,
          %Oidcc.Token{
            id: %Oidcc.Token.Id{token: id_token, claims: claims},
            access: %Oidcc.Token.Access{token: access_token},
            refresh: refresh_token
          }} <-
           Oidcc.retrieve_token(
             code,
             Claper.OidcProviderConfig,
             client_id(),
             client_secret(),
             opts()
           ),
         {:ok, oidc_user} <- validate_user(id_token, access_token, refresh_token, claims) do
      conn
      |> UserAuth.log_in_user(oidc_user.user)
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(ClaperWeb.ErrorView)
        |> render("csrf_error.html", %{error: "Authentication failed: #{inspect(reason)}"})
    end
  end

  def callback(conn, %{"error" => error} = _params) do
    conn
    |> put_status(:unauthorized)
    |> put_view(ClaperWeb.ErrorView)
    |> render("csrf_error.html", %{error: "Authentication failed: #{error}"})
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

  defp opts(pkce_challenge_or_verifier, state, nonce) do
  defp opts() do
    url = base_url()

    %{
      redirect_uri: "#{url}/users/oidc/callback",
      scopes: scopes(),
      state: state,
      nonce: nonce,
      preferred_auth_methods: [:client_secret_basic, :client_secret_post],
      code_challenge: pkce_challenge_or_verifier,
      code_challenge_method: "S256",
      require_pkce: true,
      response_mode: "query"
      preferred_auth_methods: [:client_secret_basic, :client_secret_post]
    }
  end

  defp format_refresh_token(%Oidcc.Token.Refresh{token: token}) do
    token
  end

  defp format_refresh_token(:none) do
    ""
  end

  defp validate_user(id_token, access_token, refresh_token, claims, expected_nonce) do
    if claims["nonce"] != expected_nonce do
      {:error, %{reason: :invalid_nonce, msg: "Invalid nonce"}}
    else
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
        {:error, _} -> {:error, %{reason: :invalid_user, msg: "Invalid user"}}
        {:ok, user} -> {:ok, user}
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
