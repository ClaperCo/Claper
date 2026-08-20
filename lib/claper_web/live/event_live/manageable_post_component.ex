defmodule ClaperWeb.EventLive.ManageablePostComponent do
  use ClaperWeb, :live_component

  @avatars ~w(🦊 🐙 🦉 🐸 🐼 🦋 🐬 🦈 🐢 🦎 🐝 🦩 🐧 🦦 🐨 🦁 🐯 🐻 🐰 🐮
    🐷 🐵 🦄 🐺 🦇 🐳 🐠 🦑 🦞 🦀 🐡 🐞 🦗 🕷 🦂 🐍 🦕 🦖 🦚 🦜
    🦢 🦩 🐓 🦃 🦆 🦅 🦔 🐿 🦫 🦨 🦡 🦝 🦥 🦘 🦙 🐫 🐘 🦏 🦛 🐊
    🐅 🐆 🦓 🐃 🐂 🐄 🐎 🐖 🐑 🐐 🦌 🐕 🐈 🦮 🐁 🐀 🦔 🐲 🌵 🍄)

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:readonly, fn -> false end)
      |> assign(:avatar_color, avatar_color(assigns.post))
      |> assign(:avatar_emoji, avatar_emoji(assigns.post))

    ~H"""
    <div
      id={"#{@id}"}
      class="flex items-end gap-2 group"
      x-data="{ actionsOpen: false, replying: false }"
      @click="actionsOpen = true"
      @click.outside="actionsOpen = false; replying = false"
    >
      <!-- Left: time + avatar -->
      <div class="flex flex-col items-center gap-2 shrink-0">
        <span class="text-xs text-gray-400 leading-4">
          {Calendar.strftime(@post.inserted_at, "%H:%M")}
        </span>
        <div class="avatar avatar-placeholder">
          <div class="text-white w-10 rounded-full" style={"background-color: #{@avatar_color}"}>
            <span class="text-base">{@avatar_emoji}</span>
          </div>
        </div>
      </div>
      
    <!-- Right: header + bubble -->
      <div class="flex-1 min-w-0 flex flex-col">
        <!-- Header: name + actions -->
        <div class="flex items-center gap-1 min-h-6 mb-1 ml-4">
          <p :if={@post.name} class="font-bold text-xs text-gray-700 truncate">
            {@post.name}
          </p>
          
    <!-- Actions (visible on hover) -->
          <div
            :if={!@readonly}
            class="relative z-20 ml-auto flex items-center divide-x divide-gray-200 border border-gray-200 rounded-lg group-hover:opacity-100 transition-opacity shrink-0"
            x-bind:class="actionsOpen ? 'opacity-100' : 'opacity-0'"
          >
            <div class="tooltip tooltip-bottom" data-tip={gettext("Reply")}>
              <button
                type="button"
                class="flex items-center justify-center w-8 h-6"
                @click.stop="replying = !replying"
              >
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
                  class="icon icon-tabler icons-tabler-outline icon-tabler-arrow-back-up size-4 text-gray-500"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                  <path d="M9 13l-4 -4l4 -4" />
                  <path d="M5 9h7a4 4 0 1 1 0 8h-1" />
                </svg>
              </button>
            </div>
            <div
              class="tooltip tooltip-bottom"
              data-tip={if @post.pinned, do: gettext("Unpin"), else: gettext("Pin")}
            >
              <button
                class="flex items-center justify-center w-8 h-6"
                phx-click="pin"
                phx-value-id={@post.uuid}
                phx-value-event_id={@event.uuid}
              >
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
                  class="icon icon-tabler icons-tabler-outline icon-tabler-pinned size-4 text-secondary-500"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                  <path d="M9 4v6l-2 4v2h10v-2l-2 -4v-6" />
                  <path d="M12 16l0 5" />
                  <path d="M8 4l8 0" />
                </svg>
              </button>
            </div>
            <%= if @post.attendee_identifier do %>
              <div class="tooltip tooltip-bottom" data-tip={gettext("Ban")}>
                <button
                  class="flex items-center justify-center w-8 h-6"
                  phx-click="ban"
                  phx-value-attendee_identifier={@post.attendee_identifier}
                  data-confirm={
                    gettext(
                      "Blocking this user will delete all his messages and he will not be able to join again, confirm ?"
                    )
                  }
                >
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
                    class="icon icon-tabler icons-tabler-outline icon-tabler-ban size-4 text-error"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                    <path d="M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0" />
                    <path d="M5.7 5.7l12.6 12.6" />
                  </svg>
                </button>
              </div>
            <% else %>
              <div class="tooltip tooltip-bottom" data-tip={gettext("Ban")}>
                <button
                  class="flex items-center justify-center w-8 h-6"
                  phx-click="ban"
                  phx-value-user_id={@post.user_id}
                  data-confirm={
                    gettext(
                      "Blocking this user will delete all his messages and he will not be able to join again, confirm ?"
                    )
                  }
                >
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
                    class="icon icon-tabler icons-tabler-outline icon-tabler-ban size-4 text-error"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                    <path d="M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0" />
                    <path d="M5.7 5.7l12.6 12.6" />
                  </svg>
                </button>
              </div>
            <% end %>
            <div class="tooltip tooltip-bottom" data-tip={gettext("Delete")}>
              <button
                class="flex items-center justify-center w-8 h-6"
                phx-click="delete"
                phx-value-id={@post.uuid}
                phx-value-event_id={@event.uuid}
              >
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
                  class="icon icon-tabler icons-tabler-outline icon-tabler-trash size-4 text-error"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" />
                  <path d="M4 7l16 0" />
                  <path d="M10 11l0 6" />
                  <path d="M14 11l0 6" />
                  <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" />
                  <path d="M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" />
                </svg>
              </button>
            </div>
          </div>
        </div>
        
    <!-- Message bubble with tail -->
        <% is_question = ClaperWeb.Helpers.body_without_links(@post.body) =~ "?" %>
        <% bubble_bg =
          cond do
            @post.pinned && is_question ->
              "background: linear-gradient(92deg, rgba(0,0,0,0) 0%, rgba(251,191,36,0.38) 50%, rgba(134,17,237,0.38) 98%), #fff"

            @post.pinned ->
              "background: linear-gradient(92deg, rgba(0,0,0,0) 0%, rgba(251,191,36,0.38) 98%), #fff"

            is_question ->
              "background: linear-gradient(92deg, rgba(0,0,0,0) 0%, rgba(134,17,237,0.38) 98%), #fff"

            true ->
              "background: #fff"
          end %>
        <div class="flex items-end drop-shadow-sm">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
            class="shrink-0 -mr-px"
          >
            <path d="M0 16H16V0C16 5.33333 5.33333 16 0 16Z" fill="white" />
          </svg>
          <div
            class="rounded-tl-2xl rounded-tr-2xl rounded-br-2xl flex-1 min-w-0 px-3 py-4 relative overflow-hidden"
            style={bubble_bg}
          >
            <!-- Watermark icons -->
            <div
              :if={is_question || @post.pinned}
              class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-3 opacity-100 pointer-events-none select-none"
            >
              <svg
                :if={@post.pinned}
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 13 13"
                fill="none"
              >
                <path
                  d="M0.5 12.5006L3.58667 9.41327M3.59 9.40994L1.73667 7.5566C1.10067 6.92127 1.74067 5.55927 2.61 5.5046C3.39533 5.4546 5.21333 5.73927 5.818 5.1346L7.478 3.4746C7.88933 3.0626 7.628 2.14127 7.60133 1.63327C7.56267 0.955937 8.64 0.11927 9.21133 0.690603L12.3093 3.78927C12.8827 4.36127 12.0427 5.43527 11.3673 5.39927C10.8593 5.3726 9.93733 5.11127 9.52533 5.5226L7.86533 7.1826C7.26133 7.78727 7.54533 9.6046 7.496 10.3899C7.44133 11.2599 6.07933 11.8999 5.44267 11.2633L3.59 9.40994Z"
                  stroke="white"
                  stroke-width="1.2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <span :if={is_question} class="text-2xl text-white leading-none">?</span>
            </div>
            <p class="text-sm text-gray-700 break-words relative">
              {ClaperWeb.Helpers.format_body(@post.body)}
            </p>

            <%= if @post.like_count > 0 || @post.love_count > 0 || @post.lol_count > 0 do %>
              <div class="flex items-center gap-1 mt-2 text-gray-700">
                <div
                  :if={@post.like_count > 0}
                  class="border border-gray-200 rounded-full px-2 py-2 flex items-center gap-1"
                >
                  <span class="text-sm leading-none">👍</span>
                  <span class="font-bold text-xs">{@post.like_count}</span>
                </div>
                <div
                  :if={@post.love_count > 0}
                  class="border border-gray-200 rounded-full px-2 py-2 flex items-center gap-1"
                >
                  <span class="text-sm leading-none">❤️</span>
                  <span class="font-bold text-xs">{@post.love_count}</span>
                </div>
                <div
                  :if={@post.lol_count > 0}
                  class="border border-gray-200 rounded-full px-2 py-2 flex items-center gap-1"
                >
                  <span class="text-sm leading-none">😂</span>
                  <span class="font-bold text-xs">{@post.lol_count}</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div :if={@post.reply_body} class="mt-1 ml-2 rounded-lg bg-gray-100 px-2.5 py-1.5 text-sm">
          <div class="mb-0.5 flex items-center gap-2">
            <p class="text-[10px] font-bold uppercase tracking-wide text-gray-500">
              {gettext("Moderator reply")}
            </p>
            <span :if={@post.replied_at} class="text-[10px] leading-4 text-gray-400">
              {Calendar.strftime(@post.replied_at, "%H:%M")}
            </span>
          </div>
          <p class="break-words leading-5 text-gray-700">
            {ClaperWeb.Helpers.format_body(@post.reply_body)}
          </p>
        </div>

        <form
          :if={!@readonly}
          x-show="replying"
          x-cloak
          phx-submit="reply"
          phx-value-id={@post.uuid}
          class="mt-1 ml-2 flex items-center gap-2"
        >
          <input
            type="text"
            name="reply_body"
            placeholder={gettext("Write a reply...")}
            autocomplete="off"
            class="input input-sm flex-1"
            value={@post.reply_body}
          />
          <button type="submit" class="btn btn-sm btn-primary">
            {gettext("Send")}
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp avatar_identifier(post) do
    "#{post.attendee_identifier || post.user_id || "default"}"
  end

  defp avatar_color(post) do
    hue = :erlang.phash2(avatar_identifier(post), 360)
    "hsl(#{hue}, 45%, 55%)"
  end

  defp avatar_emoji(post) do
    index = :erlang.phash2({avatar_identifier(post), :emoji}, length(@avatars))
    Enum.at(@avatars, index)
  end
end
