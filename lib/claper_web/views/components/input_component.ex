defmodule ClaperWeb.Component.Input do
  @moduledoc """
    Input component for forms
  """
  use ClaperWeb, :view_component
  use Gettext, backend: ClaperWeb.Gettext

  def text(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:label, fn
        %{required: false, name: name} -> ~s/#{name} #{gettext("(optional)")}/
        %{name: name} -> name
      end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)
      |> assign_new(:value, fn -> input_value(assigns.form, assigns.key) end)
      |> assign_new(:minlength, fn -> nil end)
      |> assign_new(:maxlength, fn -> nil end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @label, class: "block text-sm font-medium #{@labelClass}")}
      <div class="mt-1">
        {text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          value: @value,
          minlength: @minlength,
          maxlength: @maxlength,
          class:
            "#{@fieldClass} read-only:opacity-50 outline-hidden shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end

  def textarea(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)
      |> assign_new(:value, fn -> input_value(assigns.form, assigns.key) end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}")}
      <div class="mt-1">
        {text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          value: @value,
          class:
            "#{@fieldClass} read-only:opacity-50 outline-hidden shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end

  def select(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}")}
      <div class="mt-1">
        {select(@form, @key, @array,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          class:
            "#{@fieldClass} outline-hidden shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :key, :atom, required: true
  attr :label, :string, default: nil
  attr :labelClass, :string, default: nil

  def toggle(assigns) do
    ~H"""
    <div>
      {@label &&
        PhoenixHTMLHelpers.Form.label(@form, @key, @label,
          class: ["block text-sm font-medium", @labelClass || "text-gray-700"]
        )}
      {PhoenixHTMLHelpers.Form.checkbox(@form, @key, class: "toggle")}
    </div>
    """
  end

  def check(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:shortcut, fn -> nil end)

    ~H"""
    <button
      phx-click={checked(@checked, @key)}
      disabled={@disabled}
      phx-value-key={@key}
      type="button"
      class="group relative inline-flex h-5 w-10 shrink-0 cursor-pointer items-center justify-center rounded-full"
      role="switch"
      aria-checked="false"
      phx-key={@shortcut}
      phx-window-keydown={if @shortcut && not @disabled, do: checked(@checked, @key)}
    >
      <span class="pointer-events-none absolute h-full w-full rounded-md bg-white" aria-hidden="true">
      </span>
      <span
        aria-hidden="true"
        class={"#{if @checked, do: "bg-primary-500", else: "bg-gray-200"} pointer-events-none absolute mx-auto h-4 w-9 rounded-full transition-colors duration-200 ease-in-out"}
      >
      </span>
      <span
        class={"#{if @checked, do: "translate-x-5", else: "translate-x-0"} pointer-events-none absolute left-0 inline-block h-5 w-5 transform rounded-full border border-gray-200 bg-white shadow ring-0 transition-transform duration-200 ease-in-out"}
        aria-hidden="true"
      >
      </span>
    </button>
    """
  end

  def check_button(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:shortcut, fn -> nil end)
      |> assign_new(:checked, fn -> false end)

    ~H"""
    <button
      phx-click={checked(@checked, @key)}
      disabled={@disabled}
      phx-value-key={@key}
      type="button"
      class={"py-2 px-2 rounded-sm #{if @checked, do: "bg-primary-500 hover:bg-primary-600 text-white", else: "bg-gray-200 hover:bg-gray-300 text-gray-600"} flex justify-between items-center w-full gap-x-2 disabled:opacity-50 disabled:cursor-not-allowed transition ease-in-out duration-300"}
      role="switch"
      aria-checked="false"
      phx-key={@shortcut}
      phx-window-keydown={if @shortcut && not @disabled, do: checked(@checked, @key)}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  def checked(is_checked, key, js \\ %JS{})

  def checked(false, key, js) do
    js
    |> JS.push("checked", value: %{key: key, value: true})
  end

  def checked(true, key, js) do
    js
    |> JS.remove_class("translate-x-6",
      to: "#check-#{key} > span"
    )
    |> JS.add_class("translate-x-0",
      to: "#check-#{key} > span"
    )
    |> JS.remove_class("opacity-0 ease-out duration-100",
      to: "#check-#{key} > span > span"
    )
    |> JS.add_class("opacity-100 ease-in duration-200",
      to: "#check-#{key} > span > span"
    )
    |> JS.remove_class("opacity-100 ease-in duration-200",
      to: "#check-#{key} > span > span:nth-child(2)"
    )
    |> JS.add_class("opacity-0 ease-out duration-100",
      to: "#check-#{key} > span > span:nth-child(2)"
    )
    |> JS.push("checked", value: %{key: key, value: false})
  end

  def code(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @name, class: "block text-sm font-bold text-base-content")}
      <div class="mt-1 relative">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          class="pointer-events-none absolute left-4 top-3 z-10 h-6 w-6 text-gray-500"
          aria-hidden="true"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M5 9l14 0" />
          <path d="M5 15l14 0" />
          <path d="M11 4l-4 16" />
          <path d="M17 4l-4 16" />
        </svg>
        {text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          placeholder: @placeholder,
          autofocus: @autofocus,
          autocomplete: @key,
          minlength: 5,
          maxlength: 10,
          class:
            "input h-12 w-full bg-white pl-12 pr-4 uppercase read-only:opacity-50 #{if Keyword.has_key?(@form.errors, @key), do: "input-error", else: ""}"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end

  def date(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:locale, fn -> Gettext.get_locale(ClaperWeb.Gettext) end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)

    ~H"""
    <div>
      <div class="relative" id={"#{input_id(@form, @key)}-picker"} phx-hook="DateTimeLocal">
        {label(@form, :local_date, @name, class: "block text-sm font-bold text-base-content")}
        <div class="mt-1 relative">
          {hidden_input(@form, @key)}
          {datetime_local_input(@form, :local_date,
            required: @required,
            readonly: @readonly,
            autofocus: @autofocus,
            autocomplete: "off",
            lang: @locale,
            step: 300,
            class:
              "input h-12 w-full bg-white px-4 read-only:opacity-50 #{if Keyword.has_key?(@form.errors, @key), do: "input-error", else: ""}"
          )}
        </div>

        <%= if Keyword.has_key?(@form.errors, @key) do %>
          <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
        <% end %>
      </div>
    </div>
    """
  end

  def email(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:readonly, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:label, fn
        %{required: false, name: name} -> ~s/#{name} #{gettext("(optional)")}/
        %{name: name} -> name
      end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)
      |> assign_new(:value, fn -> input_value(assigns.form, assigns.key) end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @label, class: "block text-sm font-medium #{@labelClass}")}
      <div class="mt-1">
        {email_input(@form, @key,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          readonly: @readonly,
          autocomplete: @key,
          value: @value,
          class:
            "#{@fieldClass} read-only:opacity-50 shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-hidden rounded-md py-2 px-3"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end

  def password(assigns) do
    assigns =
      assigns
      |> assign_new(:required, fn -> false end)
      |> assign_new(:autofocus, fn -> false end)
      |> assign_new(:placeholder, fn -> false end)
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)

    ~H"""
    <div class="relative">
      {label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}")}
      <div class="mt-1">
        {password_input(@form, @key,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          class:
            "#{@fieldClass} shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-hidden rounded-md py-2 px-3"
        )}
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm">{error_tag(@form, @key)}</p>
      <% end %>
    </div>
    """
  end
end
