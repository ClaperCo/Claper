defmodule Claper.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :uuid, :binary_id
    field :name, :string
    field :code, :string
    field :audience_peak, :integer, default: 1
    field :started_at, :naive_datetime
    field :expired_at, :naive_datetime

    field :date_range, :string, virtual: true

    has_many :posts, Claper.Posts.Post

    has_many :leaders, Claper.Events.ActivityLeader, on_replace: :delete

    has_one :presentation_file, Claper.Presentations.PresentationFile
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
      :date_range,
      :audience_peak
    ])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> validate_required([:code])
    |> validate_date_range
  end

  def create_changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :code, :user_id, :started_at, :expired_at, :date_range])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> validate_required([:code, :started_at, :expired_at])
    |> downcase_code
  end

  def downcase_code(changeset) do
    update_change(
      changeset,
      :code,
      &(&1 |> String.downcase() |> String.split(~r"[^\w\d]", trim: true) |> List.first())
    )
  end

  defp validate_date_range(changeset) do
    date_range = get_change(changeset, :date_range)

    if date_range != nil do
      splited = date_range |> String.split(" - ")

      if splited |> Enum.count() == 2 do
        changeset
        |> put_change(:started_at, Enum.at(splited, 0))
        |> put_change(:expired_at, Enum.at(splited, 1))
      else
        add_error(changeset, :date_range, "invalid date range")
      end
    else
      start_date = get_change(changeset, :started_at)
      end_date = get_change(changeset, :expired_at)

      if start_date != nil && end_date != nil do
        changeset
        |> put_change(:date_range, "#{start_date} - #{end_date}")
      else
        changeset
      end
    end
  end

  def update_changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :code, :started_at, :expired_at, :date_range, :audience_peak])
    |> cast_assoc(:presentation_file)
    |> cast_assoc(:leaders)
    |> validate_required([:code, :started_at, :expired_at])
    |> downcase_code
  end

  def restart_changeset(event) do
    expiry =
      NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second) |> NaiveDateTime.add(48 * 3600)

    change(event, expired_at: expiry)
  end

  def subscribe(event_id) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "event:#{event_id}")
  end

  def started?(event) do
    NaiveDateTime.compare(NaiveDateTime.utc_now(), event.started_at) == :gt
  end
end
