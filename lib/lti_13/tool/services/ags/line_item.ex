defmodule Lti13.Tool.Services.AGS.LineItem do
  @derive {Jason.Encoder, except: [:id]}
  @enforce_keys [:scoreMaximum, :label, :resourceId]
  defstruct [:id, :scoreMaximum, :label, :resourceId]

  # The javascript naming convention here is important to match what the
  # LTI AGS standard expects

  @type t() :: %__MODULE__{
          id: String.t(),
          scoreMaximum: float,
          label: String.t(),
          resourceId: String.t()
        }

  def parse_resource_id(%__MODULE__{} = line_item) do
    case line_item.resourceId do
      resource_id -> resource_id
    end
  end

  def to_resource_id(resource_id) do
    Integer.to_string(resource_id)
  end
end
