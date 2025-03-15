defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

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

    {:ok, redirect_uri} =
      Oidcc.create_redirect_url(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret(),
        opts(pkce_verifier, state, nonce)
      )

    uri = Enum.join(redirect_uri, "")

    redirect(conn, external: uri)
  end

   def callback(conn, %{"code" => code, "state" => returned_state} = _params) do
    pkce_verifier = get_session(conn, :pkce_verifier)
    expected_state = get_session(conn, :oidc_state)

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
               opts(pkce_verifier, expected_state, nil)
             ),
           {:ok, oidc_user} <- validate_user(id_token, access_token, refresh_token, claims) do
        conn
  |> configure_session(renew: true)
        |> UserAuth.log_in_user(oidc_user.user)
      else
        {:error, reason} ->
          conn
          |> put_status(:unauthorized)
          |> put_view(ClaperWeb.ErrorView)
          |> render("csrf_error.html", %{error: "Authentication failed: #{inspect(reason)}"})
      end
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

  defp opts(pkce_verifier, state, nonce) do
    url = base_url()

    %{
      redirect_uri: "#{url}/users/oidc/callback",
      scopes: scopes(),
      state: state,
      nonce: nonce,
      preferred_auth_methods: [:client_secret_basic, :client_secret_post],
      pkce_verifier: pkce_verifier,
      require_pkce: true,
      response_mode: "query"
    }
  end

   defp generate_pkce_verifier do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
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
