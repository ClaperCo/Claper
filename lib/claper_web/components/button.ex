defmodule ClaperWeb.Components.Button do
  use ClaperWeb, :view_component

  attr :type, :string, default: "button"

  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary emphasis outline danger)

  attr :size, :string, default: "base", values: ~w(small base)
  attr :disabled, :boolean, default: false
  attr :loading, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(form name value)

  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      disabled={@disabled or @loading}
      class={button_classes(@variant, @size, @disabled, @loading, @class)}
      {@rest}
    >
      <%= if @loading do %>
        <svg
          class="animate-spin -ml-1 mr-3 h-5 w-5"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4">
          </circle>
          <path
            class="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
          >
          </path>
        </svg>
      <% end %>
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp button_classes(variant, size, disabled, loading, custom_class) do
    base_classes =
      "inline-flex items-center justify-center rounded-full transition-all duration-150 ease-in-out"

    variant_classes =
      case variant do
        "primary" ->
          "bg-navy text-white hover:bg-navy/80"

        "secondary" ->
          "bg-platinum text-navy hover:bg-platinum-80"

        "outline" ->
          "bg-transparent text-navy ring-2 ring-navy hover:ring-3"

        "danger" ->
          "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"

        "emphasis" ->
          "text-white bg-linear-(--gradient-primary) hover:bg-linear-(--gradient-secondary)"

        _ ->
          ""
      end

    size_classes =
      case size do
        "small" -> "px-12 py-4 font-small-body-bold text-small-body-bold"
        "base" -> "px-16 py-8 font-small-body-bold text-small-body-bold md:px-24 md:py-12 md:font-body-bold md:text-body-bold"
        _ -> ""
      end

    state_classes =
      cond do
        disabled or loading -> "opacity-50 cursor-not-allowed"
        true -> "cursor-pointer"
      end

    "#{base_classes} #{variant_classes} #{size_classes} #{state_classes} #{custom_class}"
  end
end
