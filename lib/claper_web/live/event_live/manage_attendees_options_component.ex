defmodule ClaperWeb.EventLive.ManageAttendeesOptionsComponent do
  @moduledoc false
  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  def render(assigns) do
    assigns = assigns |> assign_new(:show_shortcut, fn -> true end)

    ~H"""
    <div class="flex flex-col gap-2 border border-gray-200 rounded-2xl p-2 bg-white shadow-lg">
      <div class="flex items-center gap-2">
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
          class="icon icon-tabler icons-tabler-outline icon-tabler-mood-cog shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M21 12a9 9 0 1 0 -8.983 9" />
          <path d="M16.001 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" />
          <path d="M18.001 14.5v1.5" />
          <path d="M18.001 20v1.5" />
          <path d="M21.032 16.25l-1.299 .75" />
          <path d="M16.27 19l-1.3 .75" />
          <path d="M14.97 16.25l1.3 .75" />
          <path d="M19.733 19l1.3 .75" />
          <path d="M9 10h.01" />
          <path d="M15 10h.01" />
          <path d="M9.5 15c.658 .64 1.56 1 2.5 1" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">{gettext("Attendee Settings")}</span>
      </div>

      <div class="space-y-2 px-1">
        <.toggle_row
          label={
            if @state.chat_enabled, do: gettext("Disable messages"), else: gettext("Enable messages")
          }
          checked={@state.chat_enabled}
          key={:chat_enabled}
          shortcut={if @create == nil, do: "A", else: nil}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path
                fill-rule="evenodd"
                d="M10 2c-2.236 0-4.43.18-6.57.524C1.993 2.755 1 3.958 1 5.307v5.386c0 1.349.993 2.552 2.43 2.783 1.3.209 2.622.351 3.963.42a.75.75 0 0 1 .407.164l2.641 2.112a.75.75 0 0 0 1.184-.51l.311-2.476a.75.75 0 0 1 .663-.653c1.484-.183 2.928-.456 4.32-.814.658-.169 1.081-.8 1.081-1.49V5.307c0-1.349-.993-2.552-2.43-2.783A42.078 42.078 0 0 0 10 2ZM6.75 8a.75.75 0 0 0 0 1.5h6.5a.75.75 0 0 0 0-1.5h-6.5Zm0-3a.75.75 0 0 0 0 1.5h6.5a.75.75 0 0 0 0-1.5h-6.5Z"
                clip-rule="evenodd"
              />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.anonymous_chat_enabled,
              do: gettext("Reject anonymous messages"),
              else: gettext("Allow anonymous messages")
          }
          checked={@state.anonymous_chat_enabled}
          key={:anonymous_chat_enabled}
          shortcut={if @create == nil, do: "S", else: nil}
          disabled={!@state.chat_enabled}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M10 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM3.465 14.493a1.23 1.23 0 0 0 .41 1.412A9.957 9.957 0 0 0 10 18c2.31 0 4.438-.784 6.131-2.1.43-.333.604-.903.408-1.41a7.002 7.002 0 0 0-13.074.003Z" />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.authenticated_chat_only,
              do: gettext("Allow messages without login"),
              else: gettext("Require login to post")
          }
          checked={@state.authenticated_chat_only}
          key={:authenticated_chat_only}
          shortcut={if @create == nil, do: "F", else: nil}
          disabled={!@state.chat_enabled}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path
                fill-rule="evenodd"
                d="M10 1a4.5 4.5 0 0 0-4.5 4.5V9H5a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6a2 2 0 0 0-2-2h-.5V5.5A4.5 4.5 0 0 0 10 1Zm3 8V5.5a3 3 0 1 0-6 0V9h6Z"
                clip-rule="evenodd"
              />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.message_reaction_enabled,
              do: gettext("Disable reactions"),
              else: gettext("Enable reactions")
          }
          checked={@state.message_reaction_enabled}
          key={:message_reaction_enabled}
          shortcut={if @create == nil, do: "D", else: nil}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M9.653 16.915l-.005-.003-.019-.01a20.759 20.759 0 0 1-1.162-.682 22.045 22.045 0 0 1-2.582-1.9C4.045 12.733 2 10.352 2 7.5a4.5 4.5 0 0 1 8-2.828A4.5 4.5 0 0 1 18 7.5c0 2.852-2.044 5.233-3.885 6.82a22.049 22.049 0 0 1-3.744 2.582l-.019.01-.005.003h-.002a.723.723 0 0 1-.692 0h-.002Z" />
            </svg>
          </:icon>
        </.toggle_row>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :checked, :boolean, required: true
  attr :key, :atom, required: true
  attr :shortcut, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :show_shortcut, :boolean, default: true
  slot :icon, required: true

  defp toggle_row(assigns) do
    ~H"""
    <div class={[
      "flex items-center gap-2 rounded-full pl-2 pr-3 py-2 overflow-hidden transition-colors",
      if(@disabled, do: "opacity-50"),
      if(@checked,
        do: "bg-[#f3defa] border-b-2 border-primary",
        else: "bg-white border border-gray-200"
      )
    ]}>
      <div class={[
        "flex items-center justify-center w-8 h-8 rounded-full shrink-0",
        if(@checked, do: "bg-white text-primary-500", else: "bg-gray-100 text-secondary-500")
      ]}>
        {render_slot(@icon)}
      </div>
      <span class={["flex-1 text-xs text-gray-700", if(@checked, do: "font-semibold")]}>
        {@label}
      </span>
      <div class="flex items-center gap-x-2 shrink-0">
        <kbd :if={@show_shortcut && @shortcut} class="kbd kbd-sm">
          {@shortcut}
        </kbd>
        <button
          phx-click={ClaperWeb.Component.Input.checked(@checked, @key)}
          disabled={@disabled}
          phx-value-key={@key}
          type="button"
          class={"relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none disabled:cursor-not-allowed #{if @checked, do: "bg-primary-500", else: "bg-gray-200"}"}
          role="switch"
          aria-checked={@checked}
          phx-key={@shortcut}
          phx-window-keydown={
            if @shortcut && not @disabled, do: ClaperWeb.Component.Input.checked(@checked, @key)
          }
        >
          <span class={"pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out #{if @checked, do: "translate-x-5", else: "translate-x-0"}"}>
          </span>
        </button>
      </div>
    </div>
    """
  end
end
