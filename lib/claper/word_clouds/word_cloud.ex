defmodule Claper.WordClouds.WordCloud do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          title: String.t(),
          position: integer() | nil,
          enabled: boolean(),
          show_results: boolean(),
          max_entries: integer(),
          hidden_words: [String.t()],
          presentation_file_id: integer() | nil,
          entries: [Claper.WordClouds.Entry.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "word_clouds" do
    field :title, :string
    field :position, :integer, default: 0
    field :enabled, :boolean, default: false
    field :show_results, :boolean, default: true
    field :max_entries, :integer, default: 1
    # Match keys the presenter took out of the cloud. The entries stay stored.
    field :hidden_words, {:array, :string}, default: []

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :entries, Claper.WordClouds.Entry

    timestamps()
  end

  @doc false
  def changeset(word_cloud, attrs \\ %{}) do
    word_cloud
    |> cast(attrs, [
      :title,
      :position,
      :enabled,
      :show_results,
      :max_entries,
      :presentation_file_id
    ])
    |> validate_required([:title, :presentation_file_id, :position, :max_entries])
    |> validate_length(:title, max: 255, count: :codepoints)
    |> validate_number(:max_entries, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end
