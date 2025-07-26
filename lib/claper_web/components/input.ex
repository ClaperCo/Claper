defmodule ClaperWeb.Components.Input do
  use ClaperWeb, :view_component
  alias ClaperWeb.Components.Label

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :value, :string, default: ""
  attr :placeholder, :string, default: ""
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :errors, :list, default: []
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(autocomplete pattern minlength maxlength)

  def input(assigns) do
    ~H"""
    <div class={@class}>
      <%= if @label do %>
        <Label.label for={@id} class="ml-5">{@label}</Label.label>
      <% end %>

      <div class="relative">
        <input
          type={@type}
          name={@name}
          id={@id}
          value={@value}
          placeholder={@placeholder}
          required={@required}
          disabled={@disabled}
          class={input_classes(@value)}
          {@rest}
        />
      </div>

      <%= if @errors != [] do %>
        <div class="mt-1 ml-5">
          <%= for error <- @errors do %>
            <p class="text-xs text-red-600">{error}</p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp input_classes(value) do
    invalid_classes = "invalid:ring-2 invalid:ring-red-600"

    disabled_classes =
      "disabled:bg-platinum-80 disabled:ring-1 disabled:ring-gray-40 disabled:text-gray-60"

    base_classes =
      "w-full rounded-full transition-all duration-100 outline-none !font-display px-16 py-8 font-small-body text-small-body md:px-24 md:py-12 md:text-body md:font-body"

    empty_classes =
      if value == "" or is_nil(value) do
        "bg-platinum-20 text-black placeholder-gray-60 ring-1 ring-platinum-80"
      else
        "bg-white text-gray-900 ring ring-navy-500"
      end

    focus_classes = "focus:bg-white focus:text-gray-900 focus:ring-secondary-500 focus:ring-2"

    "#{base_classes} #{empty_classes} #{focus_classes} #{invalid_classes} #{disabled_classes}"
  end
end
