import Config
import Claper.ConfigHelpers

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

database_url =
  get_var_from_path_or_env(
    config_dir,
    "DATABASE_URL",
    "postgres://claper:claper@localhost:5432/postgres"
  )

db_ssl = get_var_from_path_or_env(config_dir, "DB_SSL", "false") |> String.to_existing_atom()

# Listen IP supports IPv4 and IPv6 addresses.
listen_ip =
  (
    str = get_var_from_path_or_env(config_dir, "LISTEN_IP") || "0.0.0.0"

    case :inet.parse_address(String.to_charlist(str)) do
      {:ok, ip_addr} ->
        ip_addr

      {:error, reason} ->
        raise "Invalid LISTEN_IP '#{str}' error: #{inspect(reason)}"
    end
  )

port = get_int_from_path_or_env(config_dir, "PORT", "4000")

secret_key_base = get_var_from_path_or_env(config_dir, "SECRET_KEY_BASE", nil)

if System.get_env("MIX_ENV") == "prod" or Application.get_env(:claper, :server, false) do
  case secret_key_base do
    nil ->
      raise "SECRET_KEY_BASE configuration option is required. See https://docs.claper.co/configuration.html#production-docker"

    key when byte_size(key) < 32 ->
      raise "SECRET_KEY_BASE must be at least 32 bytes long. See https://docs.claper.co/configuration.html#production-docker"

    _ ->
      nil
  end
end

base_url = get_var_from_path_or_env(config_dir, "BASE_URL", "http://localhost:4000")

if System.get_env("MIX_ENV") == "prod" or Application.get_env(:claper, :server, false) do
  case base_url do
    nil ->
      raise "BASE_URL configuration option is required. See https://docs.claper.co/configuration.html#production-docker"

    _ ->
      nil
  end
end

base_url = URI.parse(base_url)

if System.get_env("MIX_ENV") == "prod" or Application.get_env(:claper, :server, false) do
  if base_url.scheme not in ["http", "https"] do
    raise "BASE_URL must start with `http` or `https`. Currently configured as `#{System.get_env("BASE_URL")}`"
  end
end

max_file_size = get_int_from_path_or_env(config_dir, "MAX_FILE_SIZE_MB", 15)

enable_account_creation =
  get_var_from_path_or_env(config_dir, "ENABLE_ACCOUNT_CREATION", "true")
  |> String.to_existing_atom()

email_confirmation =
  get_var_from_path_or_env(config_dir, "EMAIL_CONFIRMATION", "false")
  |> String.to_existing_atom()

pool_size = get_int_from_path_or_env(config_dir, "POOL_SIZE", 10)
queue_target = get_int_from_path_or_env(config_dir, "QUEUE_TARGET", 5_000)

mail_transport = get_var_from_path_or_env(config_dir, "MAIL_TRANSPORT", "local")

smtp_relay = get_var_from_path_or_env(config_dir, "SMTP_RELAY", nil)
smtp_username = get_var_from_path_or_env(config_dir, "SMTP_USERNAME", nil)
smtp_password = get_var_from_path_or_env(config_dir, "SMTP_PASSWORD", nil)
smtp_ssl = get_var_from_path_or_env(config_dir, "SMTP_SSL", "true") |> String.to_existing_atom()
smtp_tls = get_var_from_path_or_env(config_dir, "SMTP_TLS", "always")
smtp_auth = get_var_from_path_or_env(config_dir, "SMTP_AUTH", "always")
smtp_port = get_int_from_path_or_env(config_dir, "SMTP_PORT", 25)

storage = get_var_from_path_or_env(config_dir, "PRESENTATION_STORAGE", "local")
if storage not in ["local", "s3"], do: raise("Invalid PRESENTATION_STORAGE value #{storage}")

s3_access_key_id = get_var_from_path_or_env(config_dir, "S3_ACCESS_KEY_ID")
s3_secret_access_key = get_var_from_path_or_env(config_dir, "S3_SECRET_ACCESS_KEY")
s3_region = get_var_from_path_or_env(config_dir, "S3_REGION")
s3_bucket = get_var_from_path_or_env(config_dir, "S3_BUCKET")

if storage == "s3" and
     not Enum.all?([s3_access_key_id, s3_secret_access_key, s3_region, s3_bucket]) do
  raise(
    "S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_REGION and S3_BUCKET required when PRESENTATION_STORAGE=s3"
  )
end

s3_scheme = get_var_from_path_or_env(config_dir, "S3_SCHEME")
s3_host = get_var_from_path_or_env(config_dir, "S3_HOST")
s3_port = get_var_from_path_or_env(config_dir, "S3_PORT")

if storage == "s3" do
  if !!s3_scheme and !s3_host, do: "S3_HOST required if S3_SCHEME is set"
  if !s3_scheme and !!s3_host, do: "S3_SCHEME required if S3_HOST is set"
end

s3_public_url =
  get_var_from_path_or_env(
    config_dir,
    "S3_PUBLIC_URL",
    if(s3_scheme && s3_host,
      do: s3_scheme <> s3_host <> if(s3_port, do: ":#{s3_port}", else: ""),
      else: "https://#{s3_bucket}.s3.#{s3_region}.amazonaws.com"
    )
  )

same_site_cookie = get_var_from_path_or_env(config_dir, "SAME_SITE_COOKIE", "Lax")

secure_cookie =
  get_var_from_path_or_env(config_dir, "SECURE_COOKIE", "false") |> String.to_existing_atom()

oidc_issuer = get_var_from_path_or_env(config_dir, "OIDC_ISSUER", "https://accounts.google.com")

oidc_client_id = get_var_from_path_or_env(config_dir, "OIDC_CLIENT_ID", nil)
oidc_client_secret = get_var_from_path_or_env(config_dir, "OIDC_CLIENT_SECRET", nil)
oidc_scopes = get_var_from_path_or_env(config_dir, "OIDC_SCOPES", "openid email profile")
oidc_provider_name = get_var_from_path_or_env(config_dir, "OIDC_PROVIDER_NAME", "OpenID Connect")
oidc_logo_url = get_var_from_path_or_env(config_dir, "OIDC_LOGO_URL", "/images/icons/openid.png")

oidc_auto_redirect_login =
  get_var_from_path_or_env(config_dir, "OIDC_AUTO_REDIRECT_LOGIN", "false")
  |> String.to_existing_atom()

oidc_property_mappings =
  get_var_from_path_or_env(config_dir, "OIDC_PROPERTY_MAPPINGS", nil)
  |> case do
    nil ->
      nil

    mappings ->
      String.split(mappings, ",")
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.into(%{}, fn [key, value] -> {key, value} end)
  end

oidc_enabled =
  !is_nil(oidc_client_id) and !is_nil(oidc_client_secret)

allow_unlink_external_provider =
  get_var_from_path_or_env(config_dir, "ALLOW_UNLINK_EXTERNAL_PROVIDER", "true")
  |> String.to_existing_atom()

logout_redirect_url = get_var_from_path_or_env(config_dir, "LOGOUT_REDIRECT_URL", nil)

languages =
  get_var_from_path_or_env(config_dir, "LANGUAGES", "en,fr,es,it,de")
  |> String.split(",")
  |> Enum.map(&String.trim/1)

config :claper, :oidc,
  enabled: oidc_enabled,
  issuer: oidc_issuer,
  client_id: oidc_client_id,
  client_secret: oidc_client_secret,
  scopes: String.split(oidc_scopes, " "),
  provider_name: oidc_provider_name,
  logo_url: oidc_logo_url,
  property_mappings: oidc_property_mappings,
  auto_redirect_login: oidc_auto_redirect_login

config :claper, Claper.Repo,
  url: database_url,
  ssl: db_ssl,
  ssl_opts: [
    verify: :verify_none
  ],
  prepare: :unnamed,
  pool_size: pool_size,
  queue_target: queue_target

config :claper, ClaperWeb.Endpoint,
  url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
  base_url: base_url,
  http: [
    ip: listen_ip,
    port: port,
    transport_options: [max_connections: :infinity],
    protocol_options: [max_request_line_length: 8192, max_header_value_length: 8192]
  ],
  secret_key_base: secret_key_base,
  same_site_cookie: same_site_cookie,
  secure_cookie: secure_cookie

config :claper,
  enable_account_creation: enable_account_creation,
  email_confirmation: email_confirmation,
  allow_unlink_external_provider: allow_unlink_external_provider,
  logout_redirect_url: logout_redirect_url,
  languages: languages

config :claper, :presentations,
  max_file_size: max_file_size,
  storage: storage,
  s3_bucket: s3_bucket,
  resolution: get_var_from_path_or_env(config_dir, "GS_JPG_RESOLUTION", "300x300"),
  s3_public_url: s3_public_url

config :claper, :mail,
  from: get_var_from_path_or_env(config_dir, "MAIL_FROM", "noreply@claper.co"),
  from_name: get_var_from_path_or_env(config_dir, "MAIL_FROM_NAME", "Claper")

config :claper, ClaperWeb.MailboxGuard,
  username: get_var_from_path_or_env(config_dir, "MAILBOX_USER", nil),
  password: get_var_from_path_or_env(config_dir, "MAILBOX_PASSWORD", nil),
  enabled:
    get_var_from_path_or_env(config_dir, "ENABLE_MAILBOX_ROUTE", "false")
    |> String.to_existing_atom()

case mail_transport do
  "smtp" ->
    config :claper, Claper.Mailer,
      adapter: Swoosh.Adapters.Mua,
      relay: smtp_relay,
      port: smtp_port

    cond do
      smtp_username && smtp_password ->
        config :claper, Claper.Mailer, auth: [username: smtp_username, password: smtp_password]

      smtp_username || smtp_password ->
        raise ArgumentError, """
        Both SMTP_USERNAME and SMTP_PASSWORD must be set for SMTP authentication.
        Please provide values for both environment variables.
        """

      true ->
        nil
    end

    config :swoosh, :api_client, false

  "postmark" ->
    config :claper, Claper.Mailer,
      adapter: Swoosh.Adapters.Postmark,
      api_key: get_var_from_path_or_env(config_dir, "POSTMARK_API_KEY", nil)

    config :swoosh, :api_client, Swoosh.ApiClient.Hackney

  _ ->
    config :claper, Claper.Mailer, adapter: Swoosh.Adapters.Local
    config :swoosh, :api_client, false
end

config :ex_aws,
  access_key_id: s3_access_key_id,
  secret_access_key: s3_secret_access_key,
  region: s3_region,
  normalize_path: false,
  s3: [scheme: s3_scheme, host: s3_host, port: s3_port]

config :swoosh, :api_client, Swoosh.ApiClient.Finch
