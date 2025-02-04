defmodule Claper.Stories.StoryVote do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          attendee_identifier: String.t() | nil,
          story_id: integer() | nil,
          story_opt_id: integer() | nil,
          user_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "story_votes" do
    field :attendee_identifier, :string

    belongs_to :story, Claper.Stories.Story
    belongs_to :story_opt, Claper.Stories.StoryOpt
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(story_vote, attrs) do
    story_vote
    |> cast(attrs, [:attendee_identifier, :user_id, :story_opt_id, :story_id])
    |> validate_required([:story_opt_id, :story_id])
  end
end
