defmodule ClaperWeb.Components.Label do
  use ClaperWeb, :view_component

  attr :for, :string, required: true
  attr :required, :boolean, default: false
  attr :class, :string, default: ""

  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class={label_classes(@class)}>
      {render_slot(@inner_block)}
      <%= if @required do %>
        <span class="text-red-500 ml-1">*</span>
      <% end %>
    </label>
    """
  end

  defp label_classes(custom_class) do
    base_classes = "block text-sm font-medium text-gray-700 mb-2"
    "#{base_classes} #{custom_class}"
  end
end
