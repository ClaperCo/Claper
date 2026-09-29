defmodule ClaperWeb.EventLive.ScaleComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="font-display">
      <div id="extended-scale" class="w-full rounded-2xl bg-gray-900 p-4 text-gray-100">
        <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Current slider")}</p>
        <p class="mb-1 text-lg font-bold leading-snug text-white">{@scale.title}</p>

        <form
          :if={is_nil(@response)}
          id={"#{@id}-form"}
          phx-change="scale-select"
          phx-submit="submit-scale"
        >
          <p class="mb-4 text-sm text-gray-400">{gettext("Move the slider and send your answer")}</p>
          <p class="mb-2 text-center text-3xl font-bold text-primary-300">{@selected}</p>
          <input
            type="range"
            name="value"
            phx-debounce="100"
            min={@scale.min_value}
            max={@scale.max_value}
            step={@scale.step}
            value={@selected}
            aria-label={@scale.title}
            class="range range-primary w-full"
          />
          <div class="mt-1 flex justify-between gap-4 text-xs text-gray-400">
            <span>{@scale.min_label || @scale.min_value}</span>
            <span class="text-right">{@scale.max_label || @scale.max_value}</span>
          </div>
          <button
            type="submit"
            phx-disable-with="..."
            class="btn-gradient mt-4 w-full rounded-lg px-3 py-2 text-sm font-bold"
          >
            {gettext("Send")}
          </button>
        </form>

        <div :if={@response} data-answered class="text-sm text-gray-400">
          <p>{gettext("Thanks! Your answer has been recorded.")}</p>
          <p class="mt-1">
            {gettext("Your answer")}: <span class="font-bold text-white">{@response.value}</span>
          </p>
        </div>

        <div :if={@response && @results} id={"#{@id}-results"} class="mt-4">
          <dl class="grid grid-cols-3 gap-2 text-center">
            <div>
              <dt class="text-xs text-gray-400">{gettext("Average")}</dt>
              <dd class="text-2xl font-bold text-white">
                {ClaperWeb.Helpers.format_number(@results.average)}
              </dd>
            </div>
            <div>
              <dt class="text-xs text-gray-400">{gettext("Median")}</dt>
              <dd class="text-2xl font-bold text-white">
                {ClaperWeb.Helpers.format_number(@results.median)}
              </dd>
            </div>
            <div>
              <dt class="text-xs text-gray-400">{gettext("Answers")}</dt>
              <dd class="text-2xl font-bold text-white">{@results.count}</dd>
            </div>
          </dl>
          <div class="mt-3 flex h-16 items-end gap-px">
            <div
              :for={point <- @results.distribution}
              title={"#{point.value}: #{point.count}"}
              class={[
                "flex-1 rounded-t",
                point.value == @response.value && "bg-primary-300",
                point.value != @response.value && "bg-primary-700"
              ]}
              style={"height: #{max(point.weight, 2)}%"}
            >
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
