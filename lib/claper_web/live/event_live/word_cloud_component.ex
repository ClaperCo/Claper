defmodule ClaperWeb.EventLive.WordCloudComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:remaining, max(assigns.word_cloud.max_entries - length(assigns.entries), 0))
      |> assign(
        :own_words,
        Enum.reject(assigns.entries, &(&1.normalized_content in assigns.word_cloud.hidden_words))
      )

    ~H"""
    <div class="font-display">
      <div id="extended-word-cloud" class="w-full rounded-2xl bg-gray-900 p-4 text-gray-100">
        <p class="mb-1 text-xs font-semibold text-gray-400">{gettext("Current word cloud")}</p>
        <p class="mb-1 text-lg font-bold leading-snug text-white">{@word_cloud.title}</p>
        <p :if={@remaining > 0} class="mb-4 text-sm text-gray-400">
          {gettext("Type your own word or phrase")}
        </p>

        <form
          :if={@remaining > 0}
          id={"#{@id}-form-#{length(@entries)}"}
          phx-submit="submit-word"
          class="flex items-center gap-2"
        >
          <input
            type="text"
            name="word"
            maxlength="60"
            autocomplete="off"
            required
            placeholder={gettext("Type one word or a short phrase...")}
            class="input min-w-0 flex-1 border border-gray-600 bg-gray-800 text-sm text-white placeholder:text-gray-500"
          />
          <button
            type="submit"
            phx-disable-with="..."
            class="btn-gradient shrink-0 rounded-lg px-4 py-2 text-sm font-bold"
          >
            {gettext("Send")}
          </button>
        </form>

        <p :if={@remaining > 0 and @entries != []} class="mt-2 text-xs text-gray-400">
          {ngettext(
            "You can send one more word.",
            "You can send %{count} more words.",
            @remaining
          )}
        </p>

        <p :if={@remaining == 0} data-submitted class="text-sm text-gray-400">
          {gettext("Thanks! Your word has been added to the cloud.")}
        </p>

        <div :if={@own_words != []} class="mt-3 flex flex-wrap gap-1">
          <span
            :for={entry <- @own_words}
            class="rounded-full bg-gray-800 px-3 py-1 text-xs font-semibold text-gray-200"
          >
            {entry.content}
          </span>
        </div>

        <div
          :if={@word_cloud.show_results and @entries != [] and @words != []}
          id={"#{@id}-cloud"}
          class="mt-4 flex flex-wrap items-baseline justify-center gap-x-3 gap-y-1 py-2"
        >
          <span
            :for={word <- @words}
            class="font-bold text-primary-300"
            style={"font-size: #{ClaperWeb.Helpers.word_size(word.percentage)}px"}
          >
            {word.text}
          </span>
        </div>
      </div>
    </div>
    """
  end
end
