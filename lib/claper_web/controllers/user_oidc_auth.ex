defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  @doc false
  def new(conn, _params) do
    # Generate a secure random state (at least 8 chars)
    state = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
    opts_with_state = Map.put(opts(), :state, state)

    {:ok, redirect_uri} =
      Oidcc.create_redirect_url(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret(),
        opts_with_state
      )

    uri = Enum.join(redirect_uri, "")

    conn
    |> put_session("oidc_state", state)
    |> redirect(external: uri)
  end

  def callback(conn, %{"code" => code, "state" => state_param} = _params) do
    session_state = get_session(conn, "oidc_state")

    cond do
      is_nil(session_state) or is_nil(state_param) or session_state != state_param ->
        conn
        |> put_status(:unauthorized)
        |> put_view(ClaperWeb.ErrorView)
        |> render("csrf_error.html", %{error: "Authentication failed: invalid or missing state parameter"})

      true ->
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
          |> delete_session("oidc_state")
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

  defp opts() do
    url = base_url()

    %{
      redirect_uri: "#{url}/users/oidc/callback",
      scopes: scopes(),
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
