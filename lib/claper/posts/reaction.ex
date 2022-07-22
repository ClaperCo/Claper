defmodule Claper.Posts.Reaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "reactions" do
    field :icon, :string
    field :attendee_identifier, :string

    belongs_to :post, Claper.Posts.Post
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:icon, :attendee_identifier, :user_id, :post_id])
    |> validate_required([:icon, :post_id])
  end
end
