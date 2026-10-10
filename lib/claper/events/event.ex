defmodule Claper.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    max_limit: 100,
    default_limit: 20,
    pagination_types: [:page],
    filterable: [:name, :code, :user_email],
    sortable: [:name, :code, :started_at, :expired_at, :audience_peak],
    default_order: %{
      order_by: [:started_at],
      order_directions: [:desc]
    },
    adapter_opts: [
      join_fields: [
        user_email: [
          binding: :user,
          field: :email,
          path: [:user, :email]
        ]
      ]
    ]
  }

  @type t :: %__MODULE__{
          id: integer(),
          uuid: Ecto.UUID.t(),
          name: String.t() | nil,
          code: String.t(),
          audience_peak: integer() | nil,
          started_at: NaiveDateTime.t() | nil,
          expired_at: NaiveDateTime.t() | nil,
          posts: [Claper.Posts.Post.t()] | nil,
          leaders: [Claper.Events.ActivityLeader.t()] | nil,
          presentation_file: Claper.Presentations.PresentationFile.t() | nil,
          user: Claper.Accounts.User.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "events" do
    field :uuid, :binary_id
    field :name, :string
    field :code, :string
    field :audience_peak, :integer, default: 0
    field :started_at, :naive_datetime
    field :expired_at, :naive_datetime

    has_many :posts, Claper.Posts.Post
    has_many :leaders, Claper.Events.ActivityLeader, on_replace: :delete

    has_one :presentation_file, Claper.Presentations.PresentationFile
    has_one :lti_resource, Lti13.Resources.Resource

    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :name,
      :code,
      :started_at,
      :expired_at,
      :audience_peak,
      :user_id
    ])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> validate_required([:name, :code])
  end

  def create_changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :code, :user_id, :started_at, :expired_at])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> downcase_code
    |> validate_required([:name, :code, :user_id])
    |> validate_length(:code, min: 5, max: 10)
    |> validate_length(:name, min: 5, max: 50)
    |> put_change(:uuid, Ecto.UUID.generate())
  end

  def downcase_code(changeset) do
    case fetch_change(changeset, :code) do
      {:ok, nil} ->
        changeset

      {:ok, code} ->
        put_change(
          changeset,
          :code,
          code |> String.downcase() |> String.split(~r"[^\w\d]", trim: true) |> List.first()
        )

      :error ->
        changeset
    end
  end

  def update_changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :code, :started_at, :expired_at, :audience_peak, :user_id])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> downcase_code
    |> validate_required([:name, :code, :user_id])
    |> validate_length(:code, min: 5, max: 10)
    |> validate_length(:name, min: 5, max: 50)
  end

  def restart_changeset(event) do
    expiry =
      NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) |> NaiveDateTime.add(48 * 3600)

    change(event, expired_at: expiry)
  end

  def subscribe(event_uuid) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event_uuid}")
  end

  def unscheduled?(event), do: is_nil(event.started_at)

  def started?(%{started_at: nil}), do: true

  def started?(event) do
    NaiveDateTime.compare(NaiveDateTime.utc_now(), event.started_at) == :gt
  end

  def finished?(event) do
    event.expired_at && NaiveDateTime.compare(NaiveDateTime.utc_now(), event.expired_at) == :gt
  end
end
