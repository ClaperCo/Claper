defmodule Claper.Accounts.Oidc.Provider do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          slug: String.t(),
          issuer: String.t(),
          client_id: String.t(),
          client_secret: String.t(),
          redirect_uri: String.t(),
          scope: String.t(),
          active: boolean(),
          position: integer(),
          response_type: String.t(),
          response_mode: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "oidc_providers" do
    field :name, :string
    field :slug, :string
    field :issuer, :string
    field :client_id, :string
    field :client_secret, :string
    field :redirect_uri, :string
    field :scope, :string, default: "openid email profile"
    field :active, :boolean, default: true
    field :position, :integer, default: 0
    field :response_type, :string, default: "code"
    field :response_mode, :string, default: "query"

    timestamps()
  end

  @doc """
  A changeset for creating or updating an OIDC provider.
  """
  def changeset(provider, attrs) do
    provider
    |> cast(attrs, [
      :name,
      :slug,
      :issuer,
      :client_id,
      :client_secret,
      :redirect_uri,
      :scope,
      :active,
      :position,
      :response_type,
      :response_mode
    ])
    |> put_slug()
    |> validate_required([:name, :slug, :issuer, :client_id, :client_secret, :redirect_uri])
    |> validate_format(:slug, ~r/^[a-z0-9]+(-[a-z0-9]+)*$/,
      message: "must contain lowercase letters, digits and single hyphens"
    )
    |> validate_format(:issuer, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_format(:redirect_uri, ~r/^https?:\/\//,
      message: "must start with http:// or https://"
    )
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
    |> unique_constraint(:issuer)
  end

  @doc """
  Derives the slug from the display name when the caller did not set one.
  """
  def put_slug(changeset) do
    case {get_field(changeset, :slug), get_field(changeset, :name)} do
      {slug, _name} when is_binary(slug) and slug != "" ->
        changeset

      {_slug, name} when is_binary(name) ->
        put_change(changeset, :slug, slugify(name))

      _ ->
        changeset
    end
  end

  @doc """
  Turns a display name into a URL-safe identifier.
  """
  def slugify(name) do
    name
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
