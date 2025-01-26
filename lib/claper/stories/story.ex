defmodule Claper.Stories.Story do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          total: integer() | nil,
          enabled: boolean() | nil,
          multiple: boolean() | nil,
          presentation_file_id: integer() | nil,
          story_opts: [Claper.Stories.StoryOpt.t()],
          story_votes: [Claper.Stories.StoryVote.t()] | nil,
          story_result: integer() | 0,
          show_results: boolean() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "stories" do
    field :title, :string
    field :position, :integer
    field :total, :integer, virtual: true
    field :enabled, :boolean
    field :multiple, :boolean
    field :show_results, :boolean
    field :story_result, :integer

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :story_opts, Claper.Stories.StoryOpt, on_replace: :delete
    has_many :story_votes, Claper.Stories.StoryVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(story, attrs) do
    story
    |> cast(attrs, [
      :title,
      :presentation_file_id,
      :position,
      :enabled,
      :total,
      :multiple,
      :story_result,
      :show_results
    ])
    |> cast_assoc(:story_opts, required: true)
    |> validate_required([:title, :presentation_file_id, :position])
    |> validate_length(:title, max: 255)
  end
end
