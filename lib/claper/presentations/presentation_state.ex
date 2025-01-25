defmodule Claper.Presentations.PresentationState do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          position: integer() | nil,
          chat_visible: boolean() | nil,
          story_visible: boolean() | nil,
          poll_visible: boolean() | nil,
          join_screen_visible: boolean() | nil,
          chat_enabled: boolean() | nil,
          anonymous_chat_enabled: boolean() | nil,
          message_reaction_enabled: boolean() | nil,
          banned: [String.t()] | nil,
          show_only_pinned: boolean() | nil,
          presentation_file_id: integer() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "presentation_states" do
    field :position, :integer
    field :chat_visible, :boolean
    field :poll_visible, :boolean
    field :story_visible, :boolean
    field :join_screen_visible, :boolean
    field :chat_enabled, :boolean
    field :anonymous_chat_enabled, :boolean
    field :message_reaction_enabled, :boolean, default: true
    field :banned, {:array, :string}, default: []
    field :show_only_pinned, :boolean, default: false

    belongs_to :presentation_file, Claper.Presentations.PresentationFile

    timestamps()
  end

  @doc false
  def changeset(presentation_state, attrs) do
    presentation_state
    |> cast(attrs, [
      :position,
      :chat_visible,
      :poll_visible,
      :story_visible,
      :join_screen_visible,
      :banned,
      :presentation_file_id,
      :chat_enabled,
      :anonymous_chat_enabled,
      :show_only_pinned,
      :message_reaction_enabled
    ])
    |> validate_required([])
  end
end
