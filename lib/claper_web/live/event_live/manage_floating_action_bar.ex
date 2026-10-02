defmodule ClaperWeb.EventLive.ManageFloatingActionBar do
  use ClaperWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="fixed bottom-6 left-1/2 -translate-x-1/2 z-40">
      <div class="flex items-center gap-2 bg-white rounded-full shadow-lg px-2 py-2 border border-gray-100">
        <.action_item
          patch={~p"/e/#{@event_code}/manage/add/poll"}
          title={gettext("Poll")}
          label={gettext("Polls")}
          description={gettext("Add a poll to gauge your audience's opinion.")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
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
        </.action_item>

        <.action_item
          patch={~p"/e/#{@event_code}/manage/add/form"}
          title={gettext("Form")}
          label={gettext("Forms")}
          description={gettext("Create a form to collect feedback from your audience.")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            stroke-width="2"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"
            />
          </svg>
        </.action_item>

        <.action_item
          patch={~p"/e/#{@event_code}/manage/add/embed"}
          title={gettext("Web Content")}
          label={gettext("Web Content")}
          description={gettext("Embed external web content into your presentation.")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M14.25 9.75L16.5 12l-2.25 2.25m-4.5 0L7.5 12l2.25-2.25M6 20.25h12A2.25 2.25 0 0020.25 18V6A2.25 2.25 0 0018 3.75H6A2.25 2.25 0 003.75 6v12A2.25 2.25 0 006 20.25z"
            />
          </svg>
        </.action_item>

        <.action_item
          patch={~p"/e/#{@event_code}/manage/add/quiz"}
          title={gettext("Quiz")}
          label={gettext("Quiz")}
          description={gettext("Test your audience's knowledge with a quiz.")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 5.25h.008v.008H12v-.008Z"
            />
          </svg>
        </.action_item>

        <.action_item
          patch={~p"/e/#{@event_code}/manage/add/word_cloud"}
          title={gettext("Word Cloud")}
          label={gettext("Word Cloud")}
          description={gettext("Let your audience answer in their own words.")}
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 15a4.5 4.5 0 0 0 4.5 4.5H18a3.75 3.75 0 0 0 1.332-7.257 3 3 0 0 0-3.758-3.848 5.25 5.25 0 0 0-10.233 2.33A4.502 4.502 0 0 0 2.25 15Z"
            />
          </svg>
        </.action_item>
      </div>
    </div>
    """
  end

  defp action_item(assigns) do
    ~H"""
    <div class="relative group">
      <.link
        patch={@patch}
        class="relative flex flex-col items-center justify-center gap-0.5 h-16 px-4 py-1.5 rounded-full text-gray-800 transition-all duration-200 hover:bg-primary-50 hover:border hover:border-primary-500 hover:text-primary-600 border border-transparent"
      >
        <div class="text-primary-500">
          {render_slot(@inner_block)}
        </div>
        <span class="font-bold text-sm leading-normal">{@label}</span>
      </.link>

      <div class="pointer-events-none opacity-0 group-hover:opacity-100 transition-opacity duration-200 absolute bottom-full left-1/2 -translate-x-1/2 mb-4 w-72 z-50">
        <div class="bg-white border border-gray-100 rounded-3xl p-4 shadow-lg">
          <p class="font-bold text-base text-gray-900 leading-normal">{@title}</p>
          <p class="text-base text-gray-900 leading-normal mt-2">{@description}</p>
        </div>
      </div>
    </div>
    """
  end
end
