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
            "#{@fieldClass} read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-4 px-3"
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
            "#{@fieldClass} read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 focus:ring-2 block w-full text-lg border-gray-300 rounded-md py-4 px-3"
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
            "#{@fieldClass} outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-4 px-3"
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
    <!-- Enabled: "bg-indigo-600", Not Enabled: "bg-gray-200" -->
    <button
      phx-click={checked(@checked, @key)}
      disabled={@disabled}
      phx-value-key={@key}
      id={"check-#{@key}"}
      type="button"
      class={"#{if @checked, do: 'bg-primary-600', else: 'bg-gray-200'} relative inline-flex flex-shrink-0 h-8 w-14 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200"}
      role="switch"
      aria-checked="false"
      phx-key={@shortcut}
      phx-window-keydown={if @shortcut && not @disabled, do: checked(@checked, @key)}
    >
      <!-- Enabled: "translate-x-5", Not Enabled: "translate-x-0" -->
      <span class={"#{if @checked, do: 'translate-x-6', else: 'translate-x-0'} pointer-events-none relative inline-block h-7 w-7 rounded-full bg-white shadow transform ring-0 transition ease-in-out duration-200"}>
        <!-- Enabled: "opacity-0 ease-out duration-100", Not Enabled: "opacity-100 ease-in duration-200" -->
        <span
          class={"#{if @checked, do: 'opacity-0 ease-out duration-100', else: 'opacity-100 ease-in duration-200'} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"}
          aria-hidden="true"
        >
          <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 12 12">
            <path
              d="M4 8l2-2m0 0l2-2M6 6L4 4m2 2l2 2"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </span>
        <!-- Enabled: "opacity-100 ease-in duration-200", Not Enabled: "opacity-0 ease-out duration-100" -->
        <span
          class={"#{if @checked, do: 'opacity-100 ease-in duration-200', else: 'opacity-0 ease-out duration-100'} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"}
          aria-hidden="true"
        >
          <svg class="h-5 w-5 text-primary-400" fill="currentColor" viewBox="0 0 12 12">
            <path d="M3.707 5.293a1 1 0 00-1.414 1.414l1.414-1.414zM5 8l-.707.707a1 1 0 001.414 0L5 8zm4.707-3.293a1 1 0 00-1.414-1.414l1.414 1.414zm-7.414 2l2 2 1.414-1.414-2-2-1.414 1.414zm3.414 2l4-4-1.414-1.414-4 4 1.414 1.414z" />
          </svg>
        </span>
      </span>
    </button>
    """
  end

  def checked(is_checked, key, js \\ %JS{})

  def checked(false, key, js) do
    js
    |> JS.remove_class("translate-x-0",
      to: "#check-#{key} > span"
    )
    |> JS.add_class("translate-x-6",
      to: "#check-#{key} > span"
    )
    |> JS.remove_class("opacity-100 ease-in duration-200",
      to: "#check-#{key} > span > span"
    )
    |> JS.add_class("opacity-0 ease-out duration-100",
      to: "#check-#{key} > span > span"
    )
    |> JS.remove_class("opacity-0 ease-out duration-100",
      to: "#check-#{key} > span > span:nth-child(2)"
    )
    |> JS.add_class("opacity-100 ease-in duration-200",
      to: "#check-#{key} > span > span:nth-child(2)"
    )
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
          class="icon absolute transition-all top-3 left-2 duration-100"
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
            "read-only:opacity-50 outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-4 pr-3 pl-12 uppercase"
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
              "outline-none shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-4 px-3 read-only:opacity-50"
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
            "#{@fieldClass} read-only:opacity-50 shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-none rounded-md py-4 px-3",
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
            "#{@fieldClass} shadow-base block w-full text-lg focus:ring-primary-500 focus:ring-2 outline-none rounded-md py-4 px-3",
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
