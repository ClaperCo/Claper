defmodule Claper.Forms.Field do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          required: boolean()
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :type, :string
    field :required, :boolean, default: true
  end

  @doc false
  def changeset(form, attrs \\ %{}) do
    form
    |> cast(attrs, [:name, :type, :required])
    |> validate_required([:name, :type])
  end
end
