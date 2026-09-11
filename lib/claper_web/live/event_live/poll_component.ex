defmodule ClaperWeb.EventLive.PollComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :focus_mode, fn -> false end)

    ~H"""
    <div class="font-display">
      <div
        :if={!@focus_mode}
        id="collapsed-poll"
        class="mx-auto hidden w-max rounded-full bg-gray-900 px-5 py-3 shadow-xl ring-1 ring-white/10"
      >
        <button
          type="button"
          class="block h-full w-full cursor-pointer"
          phx-click={toggle_poll()}
          phx-target={@myself}
        >
          <div class="flex items-center gap-2 text-white">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-primary-300"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M16 8v8m-4-5v5m-4-2v2m-2 4h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            <span class="text-sm font-bold">{gettext("See current poll")}</span>
          </div>
        </button>
      </div>

      <div
        id="extended-poll"
        class={[
          "w-full rounded-2xl bg-gray-900 p-4 text-gray-100",
          @focus_mode && "shadow-none ring-0",
          !@focus_mode && "shadow-2xl ring-1 ring-white/10"
        ]}
      >
        <div class="relative pr-8">
          <button
            :if={!@focus_mode}
            id="poll-pane"
            type="button"
            aria-label={gettext("Close")}
            class="absolute -right-1 -top-1 grid h-8 w-8 place-items-center rounded-full text-gray-400 transition-colors hover:bg-white/10 hover:text-white"
            phx-click={toggle_poll()}
            phx-target={@myself}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Current poll")}</p>

          <p class="mb-1 text-lg font-bold leading-snug text-white">{@poll.title}</p>

          <%= cond do %>
            <% @poll.type == :word_cloud -> %>
              <p class="mb-4 text-sm text-gray-400">{gettext("Type your own word or phrase")}</p>
            <% @poll.multiple -> %>
              <p class="mb-4 text-sm text-gray-400">{gettext("Select one or multiple options")}</p>
            <% true -> %>
              <p class="mb-4 text-sm text-gray-400">{gettext("Select one option")}</p>
          <% end %>
        </div>

        <div :if={@poll.type == :word_cloud}>
          <.word_cloud_body
            poll={@poll}
            current_poll_vote={@current_poll_vote}
            show_results={@show_results}
          />
        </div>

        <div :if={@poll.type != :word_cloud}>
          <div id="poll-options" class="flex flex-col gap-2">
            <%= if (length @poll.poll_opts) > 0 do %>
              <%= for {opt, idx} <- Enum.with_index(@poll.poll_opts) do %>
                <%= if (length @current_poll_vote) > 0 do %>
                  <% voted = Enum.any?(@current_poll_vote, &(&1.poll_opt_id == opt.id)) %>
                  <div class={[
                    "relative flex shrink-0 items-center justify-between overflow-hidden rounded-xl border bg-gray-800 px-3 py-2 text-sm font-semibold text-white",
                    voted && "border-primary-400",
                    !voted && "border-gray-700"
                  ]}>
                    <div
                      style={"width: #{if @show_results, do: opt.percentage, else: 0}%;"}
                      class={[
                        "absolute inset-y-0 left-0 rounded-lg bg-primary-900/40 transition-all duration-700",
                        voted && "bg-primary-700/60"
                      ]}
                    >
                    </div>

                    <div class="z-10 flex min-w-0 items-center gap-3 text-left">
                      <span class={[
                        "grid h-4 w-4 shrink-0 place-items-center border-2",
                        @poll.multiple && "rounded",
                        !@poll.multiple && "rounded-full",
                        voted && "border-primary-300",
                        !voted && "border-gray-500"
                      ]}>
                        <span
                          :if={voted}
                          class={[
                            "h-1.5 w-1.5 bg-primary-300",
                            @poll.multiple && "rounded-sm",
                            !@poll.multiple && "rounded-full"
                          ]}
                        >
                        </span>
                      </span>
                      <span class="min-w-0 flex-1 pr-2">{opt.content}</span>
                    </div>

                    <span :if={@show_results} class="z-10 shrink-0 text-xs font-bold text-white">
                      {opt.percentage}% ({opt.vote_count})
                    </span>
                  </div>
                <% else %>
                  <button
                    id={"poll-opt-#{idx}"}
                    phx-click="select-poll-opt"
                    phx-value-opt={idx}
                    aria-pressed={to_string(Enum.member?(@selected_poll_opt, "#{idx}"))}
                    class={[
                      "relative flex shrink-0 items-center justify-between overflow-hidden rounded-xl border px-3 py-2 text-sm font-semibold text-white transition-colors",
                      Enum.member?(@selected_poll_opt, "#{idx}") &&
                        "border-primary-400 bg-primary-900/40",
                      !Enum.member?(@selected_poll_opt, "#{idx}") &&
                        "border-gray-700 bg-gray-800 hover:border-primary-400"
                    ]}
                  >
                    <div
                      style={"width: #{if @show_results, do: opt.percentage, else: 0}%;"}
                      class="absolute inset-y-0 left-0 rounded-lg bg-primary-900/40 transition-all duration-700"
                    >
                    </div>

                    <div class="z-10 flex min-w-0 items-center gap-3 text-left">
                      <span class={[
                        "grid h-4 w-4 shrink-0 place-items-center border-2",
                        @poll.multiple && "rounded",
                        !@poll.multiple && "rounded-full",
                        Enum.member?(@selected_poll_opt, "#{idx}") && "border-primary-300",
                        !Enum.member?(@selected_poll_opt, "#{idx}") && "border-gray-500"
                      ]}>
                        <span
                          :if={Enum.member?(@selected_poll_opt, "#{idx}")}
                          class={[
                            "h-1.5 w-1.5 bg-primary-300",
                            @poll.multiple && "rounded-sm",
                            !@poll.multiple && "rounded-full"
                          ]}
                        >
                        </span>
                      </span>
                      <span class="min-w-0 flex-1 pr-2">{opt.content}</span>
                    </div>

                    <span :if={@show_results} class="z-10 shrink-0 text-xs font-bold text-white">
                      {opt.percentage}% ({opt.vote_count})
                    </span>
                  </button>
                <% end %>
              <% end %>
            <% end %>
          </div>

          <%= if (length @current_poll_vote) > 0 do %>
            <button
              type="button"
              disabled
              data-submitted
              class="mt-4 inline-flex w-full cursor-not-allowed items-center justify-center gap-2 rounded-lg bg-gray-700 px-3 py-2 text-sm font-bold text-gray-400"
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
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /> <path d="M5 12l5 5l10 -10" />
              </svg>
              {gettext("Voted")}
            </button>
          <% else %>
            <%= if (length @selected_poll_opt) == 0 do %>
              <button
                type="button"
                disabled
                class="mt-4 w-full cursor-not-allowed rounded-lg bg-gray-700 px-3 py-2 text-sm font-bold text-gray-400"
              >
                {gettext("Vote")}
              </button>
            <% else %>
              <button
                phx-click="vote"
                phx-disable-with="..."
                class="btn-gradient mt-4 w-full rounded-lg px-3 py-2 text-sm font-bold transition-colors"
              >
                {gettext("Vote")}
              </button>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :poll, :map, required: true
  attr :current_poll_vote, :list, required: true
  attr :show_results, :boolean, required: true

  defp word_cloud_body(assigns) do
    already_submitted = length(assigns.current_poll_vote) > 0
    assigns = assigns |> assign(:already_submitted, already_submitted)

    ~H"""
    <div>
      <form :if={!@already_submitted} phx-submit="submit-word" class="flex items-center gap-2">
        <input
          type="text"
          name="word"
          maxlength="60"
          autocomplete="off"
          placeholder={gettext("Type one word or a short phrase...")}
          class="input input-bordered flex-1 bg-gray-800 text-white placeholder:text-gray-500"
          required
        />
        <button
          type="submit"
          phx-disable-with="..."
          class="btn-gradient rounded-lg px-4 py-2 text-sm font-bold"
        >
          {gettext("Send")}
        </button>
      </form>

      <div :if={@already_submitted && !@show_results} class="text-sm text-gray-400">
        {gettext("Thanks! Your word has been added to the cloud.")}
      </div>

      <div
        :if={@show_results && length(@poll.poll_opts) > 0}
        class="flex flex-wrap items-baseline justify-center gap-x-3 gap-y-1 py-2"
      >
        <span
          :for={opt <- @poll.poll_opts}
          class="font-bold text-primary-300"
          style={"font-size: #{ClaperWeb.Helpers.word_size(opt.percentage)}px"}
        >
          {opt.content}
        </span>
      </div>
    </div>
    """
  end

  def toggle_poll(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-poll",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-poll"
    )
  end
end
