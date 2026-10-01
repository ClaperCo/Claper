defmodule Claper.Posts.PostReply do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          uuid: Ecto.UUID.t(),
          body: String.t(),
          author_role: :host | :attendee,
          author_name: String.t() | nil,
          attendee_identifier: String.t() | nil,
          post_id: integer(),
          user_id: integer() | nil,
          post: Claper.Posts.Post.t() | Ecto.Association.NotLoaded.t(),
          user: Claper.Accounts.User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "post_replies" do
    field :uuid, :binary_id
    field :body, :string
    field :author_role, Ecto.Enum, values: [:host, :attendee]
    field :author_name, :string
    field :attendee_identifier, :string

    belongs_to :post, Claper.Posts.Post
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  def changeset(reply, attrs) do
    reply
    |> cast(attrs, [
      :body,
      :author_role,
      :author_name,
      :attendee_identifier,
      :post_id,
      :user_id
    ])
    |> validate_required([:body, :author_role, :post_id])
    |> validate_length(:body, min: 1, max: 255)
    |> validate_length(:author_name, max: 20)
    |> validate_author_identity()
    |> check_constraint(:author_role, name: :valid_author_role)
    |> check_constraint(:user_id, name: :one_reply_author)
  end

  defp validate_author_identity(changeset) do
    case {get_field(changeset, :user_id), get_field(changeset, :attendee_identifier)} do
      {nil, nil} ->
        add_error(changeset, :user_id, "must identify the reply author")

      {user_id, attendee_identifier}
      when not is_nil(user_id) and not is_nil(attendee_identifier) ->
        add_error(changeset, :user_id, "cannot have two reply authors")

      _ ->
        changeset
    end
  end
end
