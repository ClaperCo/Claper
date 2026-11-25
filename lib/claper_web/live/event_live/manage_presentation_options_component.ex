defmodule ClaperWeb.EventLive.ManagePresentationOptionsComponent do
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
          class="icon icon-tabler icons-tabler-outline icon-tabler-eye-cog shrink-0 text-[#140553]"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M10 12a2 2 0 1 0 4 0a2 2 0 0 0 -4 0" />
          <path d="M12 18c-3.6 0 -6.6 -2 -9 -6c2.4 -4 5.4 -6 9 -6c3.6 0 6.6 2 9 6" />
          <path d="M17.001 19a2 2 0 1 0 4 0a2 2 0 1 0 -4 0" />
          <path d="M19.001 15.5v1.5" />
          <path d="M19.001 21v1.5" />
          <path d="M22.032 17.25l-1.299 .75" />
          <path d="M17.27 20l-1.3 .75" />
          <path d="M15.97 17.25l1.3 .75" />
          <path d="M20.733 20l1.3 .75" />
        </svg>
        <span class="font-bold text-sm text-[#140553]">{gettext("Presentation Settings")}</span>
      </div>

      <div class="space-y-2 px-1">
        <.toggle_row
          label={
            if @state.join_screen_visible,
              do: gettext("Hide instructions to join"),
              else: gettext("Show instructions to join")
          }
          checked={@state.join_screen_visible}
          key={:join_screen_visible}
          shortcut={if @create == nil, do: "Q", else: nil}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M10 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z" />
              <path
                fill-rule="evenodd"
                d="M.664 10.59a1.651 1.651 0 0 1 0-1.186A10.004 10.004 0 0 1 10 3c4.257 0 7.893 2.66 9.336 6.41.147.381.146.804 0 1.186A10.004 10.004 0 0 1 10 17c-4.257 0-7.893-2.66-9.336-6.41ZM14 10a4 4 0 1 1-8 0 4 4 0 0 1 8 0Z"
                clip-rule="evenodd"
              />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={if @state.chat_visible, do: gettext("Hide messages"), else: gettext("Show messages")}
          checked={@state.chat_visible}
          key={:chat_visible}
          shortcut={if @create == nil, do: "W", else: nil}
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
                d="M10 3c-4.31 0-8 3.033-8 7 0 2.024.978 3.825 2.499 5.085a3.478 3.478 0 0 1-.522 1.756.75.75 0 0 0 .584 1.143 5.976 5.976 0 0 0 3.936-1.108c.487.082.99.124 1.503.124 4.31 0 8-3.033 8-7s-3.69-7-8-7Z"
                clip-rule="evenodd"
              />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.show_only_pinned,
              do: gettext("Show all messages"),
              else: gettext("Show only pinned messages")
          }
          checked={@state.show_only_pinned}
          key={:show_only_pinned}
          shortcut={if @create == nil, do: "E", else: nil}
          disabled={!@state.chat_visible}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-5 h-5"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M15 4.5l-4 4l-4 1.5l-1.5 1.5l7 7l1.5 -1.5l1.5 -4l4 -4" /><path d="M9 15l-4.5 4.5" /><path d="M14.5 4l5.5 5.5" />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.show_attendee_count,
              do: gettext("Hide attendee count"),
              else: gettext("Show attendee count")
          }
          checked={@state.show_attendee_count}
          key={:show_attendee_count}
          shortcut={if @create == nil, do: "R", else: nil}
          show_shortcut={@show_shortcut}
        >
          <:icon>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M7 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM14.5 9a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5ZM1.615 16.428a1.224 1.224 0 0 1-.569-1.175 6.002 6.002 0 0 1 11.908 0c.058.467-.172.92-.57 1.174A9.953 9.953 0 0 1 7 18a9.953 9.953 0 0 1-5.385-1.572ZM14.5 16h-.106c.07-.297.088-.611.048-.933a7.47 7.47 0 0 0-1.588-3.755 4.502 4.502 0 0 1 5.874 2.636.818.818 0 0 1-.36.98A7.465 7.465 0 0 1 14.5 16Z" />
            </svg>
          </:icon>
        </.toggle_row>
        <.toggle_row
          label={
            if @state.interactions_beside_comments != false,
              do: gettext("Show results over the slide"),
              else: gettext("Show results beside the slide")
          }
          checked={@state.interactions_beside_comments != false}
          key={:interactions_beside_comments}
          shortcut={if @create == nil, do: "X", else: nil}
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
                d="M2 4.75A.75.75 0 0 1 2.75 4h3.5a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-3.5a.75.75 0 0 1-.75-.75V4.75ZM8 4.75A.75.75 0 0 1 8.75 4h8.5a.75.75 0 0 1 .75.75v10.5a.75.75 0 0 1-.75.75h-8.5a.75.75 0 0 1-.75-.75V4.75Z"
                clip-rule="evenodd"
              />
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
