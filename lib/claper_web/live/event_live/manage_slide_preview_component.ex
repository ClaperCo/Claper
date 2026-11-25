defmodule ClaperWeb.EventLive.ManageSlidePreviewComponent do
  use ClaperWeb, :live_component

  alias Claper.Presentations

  def render(assigns) do
    slide_urls = Presentations.get_slide_urls(assigns.presentation_file)
    current_slide_url = Enum.at(slide_urls, assigns.current_position)
    assigns = assign(assigns, :current_slide_url, current_slide_url)

    ~H"""
    <div
      id="slide-pointer"
      phx-hook="PointerSender"
      data-position={@current_position}
      class="flex flex-col h-full"
    >
      <div class="px-4 py-3 flex items-center justify-between">
        <div class="flex items-center gap-x-2">
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
            class="icon icon-tabler icons-tabler-outline icon-tabler-eye shrink-0 text-[#140553]"
          >
            <path stroke="none" d="M0 0h24v24H0z" fill="none" />
            <path d="M10 12a2 2 0 1 0 4 0a2 2 0 0 0 -4 0" />
            <path d="M21 12c-2.4 4 -5.4 6 -9 6c-3.6 0 -6.6 -2 -9 -6c2.4 -4 5.4 -6 9 -6c3.6 0 6.6 2 9 6" />
          </svg>
          <span class="font-bold text-sm text-[#140553]">{gettext("Preview")}</span>
        </div>
        <div class="flex items-center gap-x-2">
          <button
            type="button"
            data-pointer-toggle
            aria-pressed="false"
            title={gettext("Toggle virtual pointer (L)")}
            aria-label={gettext("Toggle virtual pointer (L)")}
            class="flex items-center gap-x-2 rounded-full bg-gray-100 px-4 py-2 text-sm text-secondary-500 transition-colors hover:bg-gray-200 aria-pressed:bg-green-600 aria-pressed:text-white"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-5 h-5"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none" />
              <path d="M12 12m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" />
              <path d="M12 3v3" />
              <path d="M12 18v3" />
              <path d="M3 12h3" />
              <path d="M18 12h3" />
            </svg>
            <span class="font-normal">{gettext("Pointer")}</span>
          </button>
          <div class="flex items-center gap-x-2 bg-gray-100 rounded-full px-4 py-2 text-sm text-secondary-500">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 20 20" fill="none">
              <path
                d="M2.5 3.3335H17.5M3.33333 3.3335V11.6668C3.33333 12.1089 3.50893 12.5328 3.82149 12.8453C4.13405 13.1579 4.55797 13.3335 5 13.3335H15C15.442 13.3335 15.866 13.1579 16.1785 12.8453C16.4911 12.5328 16.6667 12.1089 16.6667 11.6668V3.3335M10 13.3335V16.6668M7.5 16.6668H12.5"
                stroke="currentColor"
                stroke-width="1.7"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M6.66699 10.0003L9.16699 7.50033L10.8337 9.16699L13.3337 6.66699"
                stroke="currentColor"
                stroke-width="1.7"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
            <span class="font-normal">{@current_position + 1}/ {@total_slides}</span>
          </div>
        </div>
      </div>
      <div
        :if={@missing_slide_thumbnails}
        class="mx-4 mb-2 rounded-xl border border-dashed border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-900"
      >
        <div class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <p class="font-semibold">{gettext("No thumbnails are available")}</p>
            <p class="mt-1 text-xs text-amber-800">
              {gettext("Regenerate them to restore the presentation preview sidebar.")}
            </p>
          </div>
          <button
            phx-click="regenerate-thumbnails"
            type="button"
            data-confirm={gettext("No thumbnails are available. Regenerate them?")}
            disabled={@thumbnail_regeneration_in_progress}
            class="btn btn-sm btn-warning"
          >
            {if @thumbnail_regeneration_in_progress,
              do: gettext("Regenerating..."),
              else: gettext("Regenerate thumbnails")}
          </button>
        </div>
      </div>
      <div class="flex-1 flex items-center justify-center gap-x-4 px-4 py-2 overflow-hidden">
        <div class="flex-shrink-0">
          <button
            :if={@current_position > 0}
            phx-click="current-page"
            phx-value-page={@current_position - 1}
            class="btn btn-circle bg-primary-50 border-none hover:bg-primary-100"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 rotate-180"
              viewBox="0 0 16 16"
              fill="none"
            >
              <path
                d="M-0.000155798 8.91984L-0.000155623 6.91984L11.9998 6.91984L6.49984 1.41984L7.91985 -0.000157095L15.8398 7.91984L7.91984 15.8398L6.49984 14.4198L11.9998 8.91984L-0.000155798 8.91984Z"
                fill="currentColor"
              />
            </svg>
          </button>
          <div
            :if={@current_position <= 0}
            class="btn btn-circle bg-gray-100 border-none opacity-50 cursor-not-allowed"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 text-gray-400 rotate-180"
              viewBox="0 0 16 16"
              fill="none"
            >
              <path
                d="M-0.000155798 8.91984L-0.000155623 6.91984L11.9998 6.91984L6.49984 1.41984L7.91985 -0.000157095L15.8398 7.91984L7.91984 15.8398L6.49984 14.4198L11.9998 8.91984L-0.000155798 8.91984Z"
                fill="currentColor"
              />
            </svg>
          </div>
        </div>

        <div
          data-pointer-surface
          class="relative h-full aspect-video bg-white rounded-lg border border-gray-200 overflow-hidden"
        >
          <img
            :if={@current_slide_url}
            data-pointer-image
            src={@current_slide_url}
            class="w-full h-full object-contain"
            alt={"Slide #{@current_position + 1}"}
          />
          <div
            :if={!@current_slide_url}
            class="w-full h-full flex items-center justify-center text-gray-400"
          >
            <span>{gettext("No slide available")}</span>
          </div>
          <div
            id="slide-pointer-host"
            data-pointer-host
            phx-update="ignore"
            class="pointer-events-none absolute inset-0 z-10 overflow-hidden"
            aria-hidden="true"
          >
            <span
              data-pointer-dot
              class="hidden absolute h-2 w-2 -translate-x-1/2 -translate-y-1/2 rounded-full bg-green-500 shadow-[0_0_5px_2px_rgba(34,197,94,0.7)]"
            >
            </span>
          </div>
        </div>

        <div class="flex-shrink-0">
          <button
            :if={@current_position < @total_slides - 1}
            phx-click="current-page"
            phx-value-page={@current_position + 1}
            class="btn btn-circle bg-primary-50 border-none hover:bg-primary-100"
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 16 16" fill="none">
              <path
                d="M-0.000155798 8.91984L-0.000155623 6.91984L11.9998 6.91984L6.49984 1.41984L7.91985 -0.000157095L15.8398 7.91984L7.91984 15.8398L6.49984 14.4198L11.9998 8.91984L-0.000155798 8.91984Z"
                fill="currentColor"
              />
            </svg>
          </button>
          <div
            :if={@current_position >= @total_slides - 1}
            class="btn btn-circle bg-gray-100 border-none opacity-50 cursor-not-allowed"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 text-gray-400"
              viewBox="0 0 16 16"
              fill="none"
            >
              <path
                d="M-0.000155798 8.91984L-0.000155623 6.91984L11.9998 6.91984L6.49984 1.41984L7.91985 -0.000157095L15.8398 7.91984L7.91984 15.8398L6.49984 14.4198L11.9998 8.91984L-0.000155798 8.91984Z"
                fill="currentColor"
              />
            </svg>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
