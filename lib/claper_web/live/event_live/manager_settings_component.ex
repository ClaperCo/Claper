defmodule ClaperWeb.EventLive.ManagerSettingsComponent do
  use ClaperWeb, :live_component

  def render(assigns) do
    assigns = assigns |> assign_new(:show_shortcut, fn -> true end)

    ~H"""
    <div class="grid grid-cols-1 @md:grid-cols-2 space-x-2">
      <div>
        <span class="font-semibold text-lg">
          <%= gettext("Presentation settings") %>
        </span>

        <div class="flex space-x-2 items-center mt-3">
          <ClaperWeb.Component.Input.check
            key={:join_screen_visible}
            checked={@state.join_screen_visible}
            shortcut={if @create == nil, do: "Q", else: nil}
          />
          <span>
            <%= gettext("Show instructions (QR Code)") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              q
            </code>
          </span>
        </div>

        <div class="flex space-x-2 items-center mt-3">
          <ClaperWeb.Component.Input.check
            key={:chat_visible}
            checked={@state.chat_visible}
            shortcut={if @create == nil, do: "W", else: nil}
          />
          <span>
            <%= gettext("Show messages") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              w
            </code>
          </span>
        </div>

        <div
          class={"#{if !@state.chat_visible, do: "opacity-50"} flex space-x-2 items-center mt-3"}
          title={
            if !@state.chat_visible,
              do: gettext("Show messages to change this option"),
              else: nil
          }
        >
          <ClaperWeb.Component.Input.check
            key={:show_only_pinned}
            checked={@state.show_only_pinned}
            disabled={!@state.chat_visible}
            shortcut={if @create == nil, do: "E", else: nil}
          />
          <span>
            <%= gettext("Show only pinned messages") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              e
            </code>
          </span>
        </div>
      </div>

      <div>
        <span class="font-semibold text-lg">
          <%= gettext("Attendees settings") %>
        </span>

        <div class="flex space-x-2 items-center mt-3">
          <ClaperWeb.Component.Input.check
            key={:chat_enabled}
            checked={@state.chat_enabled}
            shortcut={if @create == nil, do: "A", else: nil}
          />
          <span>
            <%= gettext("Enable messages") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              a
            </code>
          </span>
        </div>

        <div
          class={"#{if !@state.chat_enabled, do: "opacity-50"} flex space-x-2 items-center mt-3"}
          title={
            if !@state.chat_enabled,
              do: gettext("Enable messages to change this option"),
              else: nil
          }
        >
          <ClaperWeb.Component.Input.check
            key={:anonymous_chat_enabled}
            checked={@state.anonymous_chat_enabled}
            disabled={!@state.chat_enabled}
            shortcut={if @create == nil, do: "S", else: nil}
          />
          <span>
            <%= gettext("Enable anonymous messages") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              s
            </code>
          </span>
        </div>

        <div class="flex space-x-2 items-center mt-3">
          <ClaperWeb.Component.Input.check
            key={:message_reaction_enabled}
            checked={@state.message_reaction_enabled}
            shortcut={if @create == nil, do: "D", else: nil}
          />
          <span>
            <%= gettext("Enable reactions") %>
            <code
              :if={@show_shortcut}
              class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
            >
              d
            </code>
          </span>
        </div>
      </div>
    </div>
    """
  end
end
