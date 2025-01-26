defmodule ClaperWeb.Component.Input do
  @moduledoc """
    Input component for forms
  """
  use ClaperWeb, :view_component

  def text(assigns) do
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
      <%= label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}") %>
      <div class="mt-1">
        <%= text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          value: @value,
          class:
            "#{@fieldClass} read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
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
      <%= label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}") %>
      <div class="mt-1">
        <%= text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          value: @value,
          class:
            "#{@fieldClass} read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
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
      <%= label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}") %>
      <div class="mt-1">
        <%= select(@form, @key, @array,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          autocomplete: @key,
          class:
            "#{@fieldClass} outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-2 px-3"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
      <% end %>
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
      class="group relative inline-flex h-5 w-10 flex-shrink-0 cursor-pointer items-center justify-center rounded-full"
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
      class={"py-2 px-2 rounded #{if @checked, do: "bg-primary-500 hover:bg-primary-600 text-white", else: "bg-gray-200 hover:bg-gray-300 text-gray-600"} flex justify-between items-center w-full gap-x-2 disabled:opacity-50 disabled:cursor-not-allowed transition ease-in-out duration-300"}
      role="switch"
      aria-checked="false"
      phx-key={@shortcut}
      phx-window-keydown={if @shortcut && not @disabled, do: checked(@checked, @key)}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def page_button(assigns) do
    assigns =
      assigns
      |> assign_new(:disabled, fn -> false end)
      |> assign_new(:shortcut, fn -> nil end)
      |> assign_new(:checked, fn -> false end)
      |> assign_new(:page, fn -> 1 end)

    ~H"""
    <button
      phx-click="current-page"
      disabled={@disabled}
      phx-value-page={@page}
      type="button"
      class={"py-2 px-2 rounded #{if @checked, do: "bg-primary-500 hover:bg-primary-600 text-white", else: "bg-gray-200 hover:bg-gray-300 text-gray-600"} flex justify-between items-center w-full gap-x-2 disabled:opacity-50 disabled:cursor-not-allowed transition ease-in-out duration-300"}
      aria-checked="false"
      phx-key={@shortcut}
      phx-window-keydown={if @shortcut && not @disabled, do: "current-page"}
    >
      <%= render_slot(@inner_block) %>
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

    ~H"""
    <div class="relative">
      <%= label(@form, @key, @name, class: "block text-sm font-medium text-gray-700") %>
      <div class="mt-1 relative">
        <img
          class="icon absolute transition-all top-2.5 left-2 duration-100 h-6"
          src="/images/icons/hashtag.svg"
          alt="code"
        />
        <%= text_input(@form, @key,
          required: @required,
          readonly: @readonly,
          placeholder: @placeholder,
          autofocus: @autofocus,
          autocomplete: @key,
          class:
            "read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-2 pr-3 pl-9 uppercase"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
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

    ~H"""
    <div>
      <div class="relative" id="date" phx-hook="Pickr">
        <%= label(@form, @key, @name, class: "block text-sm font-medium text-gray-700") %>
        <div class="mt-1 relative">
          <%= hidden_input(@form, @key) %>
          <%= text_input(@form, :local_date,
            autofocus: @autofocus,
            placeholder: @placeholder,
            autocomplete: false,
            class:
              "outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-2 px-3 read-only:opacity-50"
          ) %>
        </div>

        <%= if Keyword.has_key?(@form.errors, @key) do %>
          <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
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
      |> assign_new(:labelClass, fn -> "text-gray-700" end)
      |> assign_new(:fieldClass, fn -> "bg-white" end)
      |> assign_new(:value, fn -> input_value(assigns.form, assigns.key) end)

    ~H"""
    <div class="relative" x-data={"{input: '#{assigns.value}'}"}>
      <%= label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}") %>
      <div class="mt-1">
        <%= email_input(@form, @key,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          readonly: @readonly,
          autocomplete: @key,
          value: @value,
          class:
            "#{@fieldClass} read-only:opacity-50 shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-none rounded-md py-2 px-3",
          "x-model": "input",
          "x-ref": "input"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
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
      |> assign_new(:value, fn -> Map.get(assigns.form.data, assigns.key, "") end)

    ~H"""
    <div class="relative" x-data={"{input: '#{assigns.value}'}"}>
      <%= label(@form, @key, @name, class: "block text-sm font-medium #{@labelClass}") %>
      <div class="mt-1">
        <%= password_input(@form, @key,
          required: @required,
          autofocus: @autofocus,
          placeholder: @placeholder,
          class:
            "#{@fieldClass} shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-none rounded-md py-2 px-3",
          "x-model": "input",
          "x-ref": "input"
        ) %>
      </div>
      <%= if Keyword.has_key?(@form.errors, @key) do %>
        <p class="text-supporting-red-500 text-sm"><%= error_tag(@form, @key) %></p>
      <% end %>
    </div>
    """
  end
end
