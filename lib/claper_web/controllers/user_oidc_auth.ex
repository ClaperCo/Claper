defmodule ClaperWeb.UserOidcAuth do
  @moduledoc """
    Plug for OpenID Connect authentication.
  """
  alias ClaperWeb.UserAuth
  use ClaperWeb, :controller

  import Phoenix.Controller

  @doc false
  def new(conn, _params) do
    {:ok, redirect_uri} =
      Oidcc.create_redirect_url(
        Claper.OidcProviderConfig,
        client_id(),
        client_secret(),
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
      {:error, _} ->
        conn
        |> put_flash(:error, "Cannot authenticate user.")
        |> redirect(to: ~p"/users/log_in")
    end

    conn
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
      scopes: scopes()
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
