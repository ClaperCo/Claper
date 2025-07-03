defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

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
    # Generate PKCE verifier and store it in session
    pkce_verifier = generate_pkce_verifier()
    conn = put_session(conn, :pkce_verifier, pkce_verifier)

    {:ok, redirect_uri} =
      Oidcc.create_redirect_url(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret(),
        opts(pkce_verifier)
      )

    uri = Enum.join(redirect_uri, "")

    redirect(conn, external: uri)
  end

  def callback(conn, %{"code" => code} = _params) do
    # Get PKCE verifier from session
    pkce_verifier = get_session(conn, :pkce_verifier)

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
             opts(pkce_verifier)
           ),
         {:ok, oidc_user} <- validate_user(id_token, access_token, refresh_token, claims) do
      conn
      # Clean up the verifier
      |> delete_session(:pkce_verifier)
      |> UserAuth.log_in_user(oidc_user.user)
    else
      {:error, reason} ->
        conn
        # Clean up the verifier even on error
        |> delete_session(:pkce_verifier)
        |> put_status(:unauthorized)
        |> put_view(ClaperWeb.ErrorView)
        |> render("csrf_error.html", %{error: "Authentication failed: #{inspect(reason)}"})
    end
  end

  def callback(conn, %{"error" => error} = _params) do
    conn
    # Clean up the verifier even on error
    |> delete_session(:pkce_verifier)
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

  defp opts(pkce_verifier) do
    url = base_url()

    base_opts = %{
      redirect_uri: "#{url}/users/oidc/callback",
      scopes: scopes(),
      preferred_auth_methods: [:client_secret_basic, :client_secret_post],
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
