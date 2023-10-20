defmodule Claper.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :body, :string
    field :uuid, :binary_id
    field :like_count, :integer, default: 0
    field :love_count, :integer, default: 0
    field :lol_count, :integer, default: 0
    field :name, :string
    field :attendee_identifier, :string
    field :position, :integer, default: 0
    field :pinned, :boolean, default: false

    belongs_to :event, Claper.Events.Event
    belongs_to :user, Claper.Accounts.User
    has_many :reactions, Claper.Posts.Reaction

    timestamps()
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [
      :body,
      :attendee_identifier,
      :user_id,
      :like_count,
      :love_count,
      :lol_count,
      :name,
      :position,
      :pinned
    ])
    |> validate_required([:body, :position])
    |> validate_length(:body, min: 2, max: 255)
  end

  def nickname_changeset(post, attrs) do
    post
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 2, max: 20)
  end
end
