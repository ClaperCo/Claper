defmodule ClaperWeb.EventLive.PostComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    own_message =
      assigns.post.attendee_identifier == assigns.attendee_identifier ||
        (not is_nil(assigns.current_user) && assigns.post.user_id == assigns.current_user.id)

    host_message = leader?(assigns.post, assigns.event, assigns.leaders)

    assigns =
      assigns
      |> assign(:own_message, own_message)
      |> assign(:host_message, host_message)
      |> assign(:show_actions, own_message || assigns.is_leader)
      |> assign(:can_react, assigns.reaction_enabled && !own_message)
      |> assign(:author_name, author_name(assigns.post))

    ~H"""
    <article
      id={@id}
      class={[
        "relative rounded-xl border px-3 py-2 shadow-sm",
        @host_message &&
          "border-supporting-yellow-300 bg-supporting-yellow-50 text-supporting-yellow-950",
        !@host_message && @own_message && "border-gray-600 bg-gray-700 text-white",
        !@host_message && !@own_message && "border-gray-200 bg-white text-gray-900"
      ]}
    >
      <header class={[
        "mb-1 flex min-h-6 items-center gap-2",
        @can_react && @show_actions && "pr-20",
        @can_react && !@show_actions && "pr-9",
        !@can_react && @show_actions && "pr-9"
      ]}>
        <span class={[
          "truncate text-xs font-bold",
          @host_message && "text-supporting-yellow-900",
          !@host_message && @own_message && "text-gray-200",
          !@host_message && !@own_message && "text-gray-600"
        ]}>
          {@author_name}
        </span>
        <span
          :if={@host_message}
          class="inline-flex items-center gap-1 rounded-full bg-supporting-yellow-200 px-2 py-1 text-[10px] font-bold uppercase text-supporting-yellow-900"
        >
          ★ {gettext("Host")}
        </span>
        <span
          :if={pinned?(@post)}
          class="inline-flex items-center gap-1 rounded-full bg-supporting-yellow-400 px-2 py-1 text-[10px] font-bold uppercase text-supporting-yellow-900"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-3 w-3"
            viewBox="0 0 24 24"
            fill="currentColor"
            aria-hidden="true"
          >
            <path stroke="none" d="M0 0h24v24H0z" fill="none" />
            <path d="M16 3a1 1 0 0 1 .117 1.993l-.117 .007v4.764l1.894 3.789a1 1 0 0 1 .1 .331l.006 .116v2a1 1 0 0 1 -.883 .993l-.117 .007h-4v4a1 1 0 0 1 -1.993 .117l-.007 -.117v-4h-4a1 1 0 0 1 -.993 -.883l-.007 -.117v-2a1 1 0 0 1 .06 -.34l.046 -.107l1.894 -3.791v-4.762a1 1 0 0 1 -.117 -1.993l.117 -.007h8z" />
          </svg>
          {gettext("Pinned")}
        </span>
      </header>

      <button
        :if={@show_actions}
        type="button"
        aria-label={gettext("Message actions")}
        phx-click={
          JS.toggle(
            to: "#post-menu-#{@post.id}",
            out: "animate__animated animate__fadeOut",
            in: "animate__animated animate__fadeIn"
          )
        }
        phx-click-away={
          JS.hide(to: "#post-menu-#{@post.id}", transition: "animate__animated animate__fadeOut")
        }
        class={[
          "absolute right-2 top-2 grid h-11 w-11 place-items-center rounded-full text-xl leading-none",
          @own_message && !@host_message && "text-white hover:bg-white/10",
          (!@own_message || @host_message) && "text-gray-600 hover:bg-black/5"
        ]}
      >
        ⋯
      </button>

      <button
        :if={@can_react}
        type="button"
        data-message-reaction-trigger
        aria-label={gettext("React to message")}
        aria-haspopup="menu"
        phx-click={JS.toggle(to: "#reaction-menu-#{@post.id}", display: "flex")}
        class={[
          "absolute top-2 grid h-11 w-11 place-items-center rounded-full text-sm font-bold",
          @show_actions && "right-12",
          !@show_actions && "right-2",
          @own_message && !@host_message && "text-white hover:bg-white/10",
          (!@own_message || @host_message) && "text-gray-600 hover:bg-black/5"
        ]}
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path stroke="none" d="M0 0h24v24H0z" fill="none" />
          <path d="M12 20l-7.5 -7.428a5 5 0 1 1 7.5 -6.566a5 5 0 1 1 7.96 6.053" />
          <path d="M16 19h6" />
          <path d="M19 16v6" />
        </svg>
      </button>

      <div
        :if={@can_react}
        id={"reaction-menu-#{@post.id}"}
        data-message-reaction-menu
        role="menu"
        phx-click-away={JS.hide(to: "#reaction-menu-#{@post.id}")}
        class={[
          "absolute top-14 z-20 hidden items-center gap-1 rounded-full bg-gray-950 p-1.5 text-white shadow-2xl",
          @show_actions && "right-11",
          !@show_actions && "right-2"
        ]}
      >
        <button
          type="button"
          role="menuitem"
          aria-label={gettext("Thumbs up")}
          phx-click={picker_reaction_click(Enum.member?(@liked_posts, @post.id), @post.id)}
          phx-value-type="👍"
          phx-value-post-id={@post.uuid}
          class={picker_reaction_classes(Enum.member?(@liked_posts, @post.id))}
        >
          👍
        </button>
        <button
          type="button"
          role="menuitem"
          aria-label={gettext("Heart")}
          phx-click={picker_reaction_click(Enum.member?(@loved_posts, @post.id), @post.id)}
          phx-value-type="❤️"
          phx-value-post-id={@post.uuid}
          class={picker_reaction_classes(Enum.member?(@loved_posts, @post.id))}
        >
          ❤️
        </button>
        <button
          type="button"
          role="menuitem"
          aria-label={gettext("Laugh")}
          phx-click={picker_reaction_click(Enum.member?(@loled_posts, @post.id), @post.id)}
          phx-value-type="😂"
          phx-value-post-id={@post.uuid}
          class={picker_reaction_classes(Enum.member?(@loled_posts, @post.id))}
        >
          😂
        </button>
      </div>

      <div
        id={"post-menu-#{@post.id}"}
        class="absolute right-3 top-12 z-20 hidden rounded-xl bg-gray-950 px-4 py-3 text-sm shadow-2xl animate__faster"
      >
        {link(gettext("Delete"),
          to: "#",
          class: "font-semibold text-supporting-red-400",
          phx_click: "delete",
          phx_value_id: @post.uuid,
          phx_value_event_id: @event.uuid,
          data: [confirm: gettext("Are you sure?")]
        )}
      </div>

      <p class="break-words text-sm leading-5">{ClaperWeb.Helpers.format_body(@post.body)}</p>

      <div
        :if={@post.reply_body}
        class={[
          "mt-2 rounded-lg border-l-2 px-2.5 py-1.5 text-sm",
          @host_message && "border-supporting-yellow-500 bg-supporting-yellow-100/60",
          !@host_message && @own_message && "border-white/30 bg-white/10",
          !@host_message && !@own_message && "border-gray-300 bg-gray-50"
        ]}
      >
        <p class={[
          "mb-0.5 text-[10px] font-bold uppercase tracking-wide",
          @host_message && "text-supporting-yellow-900",
          !@host_message && @own_message && "text-gray-300",
          !@host_message && !@own_message && "text-gray-500"
        ]}>
          {gettext("Moderator reply")}
        </p>
        <p class="break-words leading-5">{ClaperWeb.Helpers.format_body(@post.reply_body)}</p>
      </div>

      <div
        :if={
          @reaction_enabled &&
            (@post.like_count > 0 || @post.love_count > 0 || @post.lol_count > 0)
        }
        class="mt-1.5 flex flex-wrap justify-end gap-1"
      >
        <button
          :if={@post.like_count > 0}
          type="button"
          data-reaction-chip
          disabled={@own_message}
          phx-click={if Enum.member?(@liked_posts, @post.id), do: "unreact", else: "react"}
          phx-value-type="👍"
          phx-value-post-id={@post.uuid}
          aria-pressed={to_string(Enum.member?(@liked_posts, @post.id))}
          class={
            reaction_chip_classes(
              Enum.member?(@liked_posts, @post.id),
              @own_message && !@host_message
            )
          }
        >
          <span>👍</span><span :if={@post.like_count > 0}>{@post.like_count}</span>
        </button>
        <button
          :if={@post.love_count > 0}
          data-reaction-chip
          type="button"
          disabled={@own_message}
          phx-click={if Enum.member?(@loved_posts, @post.id), do: "unreact", else: "react"}
          phx-value-type="❤️"
          phx-value-post-id={@post.uuid}
          aria-pressed={to_string(Enum.member?(@loved_posts, @post.id))}
          class={
            reaction_chip_classes(
              Enum.member?(@loved_posts, @post.id),
              @own_message && !@host_message
            )
          }
        >
          <span>❤️</span><span :if={@post.love_count > 0}>{@post.love_count}</span>
        </button>
        <button
          :if={@post.lol_count > 0}
          data-reaction-chip
          type="button"
          disabled={@own_message}
          phx-click={if Enum.member?(@loled_posts, @post.id), do: "unreact", else: "react"}
          phx-value-type="😂"
          phx-value-post-id={@post.uuid}
          aria-pressed={to_string(Enum.member?(@loled_posts, @post.id))}
          class={
            reaction_chip_classes(
              Enum.member?(@loled_posts, @post.id),
              @own_message && !@host_message
            )
          }
        >
          <span>😂</span><span :if={@post.lol_count > 0}>{@post.lol_count}</span>
        </button>
      </div>
    </article>
    """
  end

  defp author_name(%{name: name}) when is_binary(name) and name != "", do: name
  defp author_name(_post), do: gettext("Anonymous")

  defp reaction_chip_classes(selected, dark_message) do
    [
      "inline-flex h-7 min-w-7 items-center justify-center gap-1 rounded-full border px-2 text-[11px] font-semibold transition-colors",
      selected && "border-primary-400 bg-primary-100 text-primary-900",
      !selected && dark_message && "border-white/30 bg-transparent text-white hover:bg-white/10",
      !selected && !dark_message && "border-gray-300 bg-white text-gray-800 hover:bg-gray-100"
    ]
  end

  defp picker_reaction_classes(selected) do
    [
      "grid h-11 w-11 place-items-center rounded-full text-lg transition-colors hover:bg-white/10",
      selected && "bg-primary-500"
    ]
  end

  defp picker_reaction_click(selected, post_id) do
    JS.push(if(selected, do: "unreact", else: "react"))
    |> JS.hide(to: "#reaction-menu-#{post_id}")
  end

  defp leader?(post, event, leaders) do
    !is_nil(post.user_id) &&
      (post.user_id == event.user_id ||
         Enum.any?(leaders, fn leader -> leader.user_id == post.user_id end))
  end

  defp pinned?(post), do: post.pinned
end
