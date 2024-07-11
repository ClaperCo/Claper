defmodule Claper.Forms.Form do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          enabled: boolean()  | nil,
          position: integer() | nil,
          title: String.t(),
          fields: [Claper.Forms.Field.t()] | nil,
          presentation_file_id: integer() | nil,
          form_submits: [Claper.Forms.FormSubmit.t()] | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:title, :position]}
  schema "forms" do
    field :enabled, :boolean, default: true
    field :position, :integer, default: 0
    field :title, :string
    embeds_many :fields, Claper.Forms.Field, on_replace: :delete

    belongs_to :presentation_file, Claper.Presentations.PresentationFile
    has_many :form_submits, Claper.Forms.FormSubmit, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(form, attrs \\ %{}) do
    form
    |> cast(attrs, [:enabled, :title, :presentation_file_id, :position])
    |> cast_embed(:fields)
    |> validate_required([:title, :presentation_file_id, :position])
  end
end
