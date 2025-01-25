defmodule Claper.Stories.StoryOpt do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          next_slide: integer(),
          vote_count: integer(),
          percentage: float(),
          story_id: integer(),
          story: Claper.Stories.Story.t(),
          story_votes: [Claper.Stories.StoryVote.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:content, :vote_count]}
  schema "story_opts" do
    field :content, :string
    field :next_slide, :integer
    field :vote_count, :integer
    field :percentage, :float, virtual: true

    belongs_to :story, Claper.Stories.Story
    has_many :story_votes, Claper.Stories.StoryVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(story_opt, attrs) do
    story_opt
    |> cast(attrs, [:content, :vote_count, :next_slide, :story_id])
    |> validate_required([:content, :next_slide])
    |> validate_length(:content, max: 255)
  end
end
