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
        class="absolute right-3 top-12 z-20 hidden space-y-2 rounded-xl bg-gray-950 px-4 py-3 text-sm shadow-2xl animate__faster"
      >
        <button
          type="button"
          class="block font-semibold text-white"
          data-reply-trigger
          aria-controls={"reply-form-#{@post.uuid}"}
          phx-click={
            JS.hide(to: "#post-menu-#{@post.id}")
            |> JS.show(to: "#reply-form-#{@post.uuid}", display: "flex")
            |> JS.focus(to: "#reply-input-#{@post.uuid}")
          }
        >
          {gettext("Reply")}
        </button>
        {link(gettext("Delete"),
          to: "#",
          class: "block font-semibold text-supporting-red-400",
          phx_click: "delete",
          phx_value_id: @post.uuid,
          phx_value_event_id: @event.uuid,
          data: [confirm: gettext("Are you sure?")]
        )}
      </div>

      <p class="break-words text-sm leading-5">{ClaperWeb.Helpers.format_body(@post.body)}</p>

      <div :if={@post.replies != []} class="mt-2 space-y-1.5">
        <div
          :for={reply <- @post.replies}
          id={"reply-#{reply.uuid}"}
          class={[
            "group/reply border-l-2 py-1 pl-3 pr-2 text-sm",
            @own_message && !@host_message && "border-primary-300 text-white",
            (!@own_message || @host_message) && "border-primary-400 text-gray-800"
          ]}
        >
          <div class="mb-0.5 flex min-h-5 items-center gap-2">
            <p class={[
              "text-[10px] font-bold uppercase tracking-wide",
              @own_message && !@host_message && "text-gray-300",
              (!@own_message || @host_message) && "text-gray-500"
            ]}>
              {reply_author_name(reply)}
            </p>
            <span class={[
              "text-[10px]",
              @own_message && !@host_message && "text-gray-300",
              (!@own_message || @host_message) && "text-gray-400"
            ]}>
              {Calendar.strftime(reply.inserted_at, "%H:%M")}
            </span>
            <button
              :if={can_delete_reply?(reply, @is_leader, @current_user, @attendee_identifier)}
              type="button"
              phx-click="delete-reply"
              phx-value-id={reply.uuid}
              data-confirm={gettext("Are you sure?")}
              aria-label={gettext("Delete reply")}
              class="btn btn-ghost btn-circle ml-auto !size-7 min-h-0 opacity-0 group-hover/reply:opacity-100 group-focus-within/reply:opacity-100"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="size-4 text-error"
                aria-hidden="true"
              >
                <path d="M4 7h16" />
                <path d="M10 11v6" />
                <path d="M14 11v6" />
                <path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2l1-12" />
                <path d="M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3" />
              </svg>
            </button>
          </div>
          <p class="break-words leading-5">{ClaperWeb.Helpers.format_body(reply.body)}</p>
        </div>
      </div>

      <form
        :if={@show_actions}
        id={"reply-form-#{@post.uuid}"}
        phx-submit={JS.push("reply") |> JS.hide(to: "#reply-form-#{@post.uuid}")}
        phx-value-id={@post.uuid}
        class="mt-2 hidden min-w-0 items-center gap-2"
      >
        <label for={"reply-input-#{@post.uuid}"} class="sr-only">
          {gettext("Write a reply...")}
        </label>
        <input
          id={"reply-input-#{@post.uuid}"}
          type="text"
          name="reply_body"
          placeholder={gettext("Write a reply...")}
          autocomplete="off"
          maxlength="255"
          class="input input-sm !h-9 !min-h-9 min-w-0 flex-1 bg-base-100 text-base-content"
          @keydown.stop
        />
        <button type="submit" class="btn btn-primary btn-sm !h-9 !min-h-9 shrink-0 gap-1.5">
          <img src="/images/icons/send.svg" class="h-5 w-5" alt="" />
          {gettext("Reply")}
        </button>
      </form>

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

  defp reply_author_name(%{author_role: :host}), do: gettext("Host")

  defp reply_author_name(%{author_name: name}) when is_binary(name) and name != "", do: name

  defp reply_author_name(_reply), do: gettext("Anonymous")

  defp can_delete_reply?(_reply, true, _current_user, _attendee_identifier), do: true

  defp can_delete_reply?(%{user_id: user_id}, _is_leader, %{id: user_id}, _attendee_identifier),
    do: true

  defp can_delete_reply?(
         %{attendee_identifier: attendee_identifier},
         _is_leader,
         _current_user,
         attendee_identifier
       )
       when not is_nil(attendee_identifier),
       do: true

  defp can_delete_reply?(_reply, _is_leader, _current_user, _attendee_identifier), do: false

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
