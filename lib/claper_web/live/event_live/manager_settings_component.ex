defmodule ClaperWeb.EventLive.ManagerSettingsComponent do
  use ClaperWeb, :live_component

  def render(assigns) do
    assigns = assigns |> assign_new(:show_shortcut, fn -> true end)

    ~H"""
    <div class="grid grid-cols-1 @md:grid-cols-2 @md:space-x-5 px-5 py-3">
      <div>
        <div class="flex items-center space-x-2 font-semibold text-lg">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            class="w-5 h-5"
          >
            <path d="M6.111 11.89A5.5 5.5 0 1 1 15.501 8 .75.75 0 0 0 17 8a7 7 0 1 0-11.95 4.95.75.75 0 0 0 1.06-1.06Z" />
            <path d="M8.232 6.232a2.5 2.5 0 0 0 0 3.536.75.75 0 1 1-1.06 1.06A4 4 0 1 1 14 8a.75.75 0 0 1-1.5 0 2.5 2.5 0 0 0-4.268-1.768Z" />
            <path d="M10.766 7.51a.75.75 0 0 0-1.37.365l-.492 6.861a.75.75 0 0 0 1.204.65l1.043-.799.985 3.678a.75.75 0 0 0 1.45-.388l-.978-3.646 1.292.204a.75.75 0 0 0 .74-1.16l-3.874-5.764Z" />
          </svg>

          <span><%= gettext("Interaction") %></span>
        </div>

        <%= case @current_interaction do %>
          <% %Claper.Polls.Poll{} -> %>
            <div class="flex space-x-2 space-y-1.5 items-center mt-1.5">
              <ClaperWeb.Component.Input.check_button
                key={:poll_visible}
                checked={@state.poll_visible}
                shortcut={if @create == nil, do: "Z", else: nil}
              >
                <svg
                  :if={@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                </svg>

                <svg
                  :if={!@state.poll_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                </svg>

                <span :if={@state.poll_visible}>
                  <%= gettext("Hide results on presentation") %>
                </span>
                <span :if={!@state.poll_visible}>
                  <%= gettext("Show results on presentation") %>
                </span>
                <code
                  :if={@show_shortcut}
                  class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
                >
                  z
                </code>
                <div :if={!@show_shortcut}></div>
              </ClaperWeb.Component.Input.check_button>
            </div>
          <% %Claper.Stories.Story{} -> %>
            <div class="flex space-x-2 space-y-1.5 items-center mt-1.5">
              <ClaperWeb.Component.Input.check_button
                key={:story_visible}
                checked={@state.story_visible}
                shortcut={if @create == nil, do: "Z", else: nil}
              >
                <svg
                  :if={@state.story_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                </svg>

                <svg
                  :if={!@state.story_visible}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                </svg>

                <span :if={@state.story_visible}>
                  <%= gettext("Hide results on presentation") %>
                </span>
                <span :if={!@state.story_visible}>
                  <%= gettext("Show results on presentation") %>
                </span>
                <code
                  :if={@show_shortcut}
                  class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
                >
                  z
                </code>
                <div :if={!@show_shortcut}></div>
              </ClaperWeb.Component.Input.check_button>
            </div>
            <div class="flex space-x-2 space-y-1.5 items-center mt-1.5">
              <ClaperWeb.Component.Input.page_button
                key={:story_visible}
                checked={if @current_interaction.story_result == -1, do: false, else: true}
                disabled={if @current_interaction.story_result == -1, do: true, else: false}
                page={@current_interaction.story_result - 1}
                shortcut={if @create == nil, do: "N", else: nil}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 72 72"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <g id="_xD83D__xDC69__x200D__x2696__xFE0F_">
                    <g>
                      <path d="M28.5,14.6c-0.3,0-0.7-0.2-0.9-0.5l-0.1-0.2c-0.4-0.6-0.7-1.2-0.7-2.3c0-3.3,2.7-6,6-6s6,2.7,6,6c0,0.6-0.4,1-1,1
                        c-0.6,0-1-0.4-1-1c0-2.2-1.8-4-4-4c-2.2,0-4,1.8-4,4c0,0.5,0.1,0.7,0.4,1.2l0.1,0.2c0.3,0.5,0.1,1.1-0.4,1.4
                        C28.8,14.6,28.6,14.6,28.5,14.6z" />
                    </g>
                    <g>
                      <path
                        fill="#000100"
                        d="M42,27c0,1.1-0.9,2-2,2s-2-0.9-2-2c0-1.1,0.9-2,2-2S42,25.9,42,27"
                      />
                    </g>
                    <g>
                      <path
                        fill="#000100"
                        d="M34,27c0,1.1-0.9,2-2,2c-1.1,0-2-0.9-2-2c0-1.1,0.9-2,2-2C33.1,25,34,25.9,34,27"
                      />
                    </g>
                    <g>
                      <path
                        fill="#000100"
                        d="M36,37c-1.2,0-2.3-0.3-3.4-0.9c-0.5-0.2-0.7-0.8-0.4-1.3c0.2-0.5,0.8-0.7,1.3-0.4c1.7,0.9,3.4,0.9,5.1,0
                        c0.5-0.2,1.1,0,1.3,0.4c0.2,0.5,0,1.1-0.4,1.3C38.3,36.7,37.1,37,36,37z"
                      />
                    </g>
                    <g>
                      <path d="M36,43.5c-3.8,0-7.3-2.1-9.7-5.7c-0.3-0.5-0.2-1.1,0.3-1.4c0.5-0.3,1.1-0.2,1.4,0.3c2,3.1,4.9,4.8,8,4.8
                        c5.7,0,10.3-5.9,10.3-13.2c0-1.1-0.1-2.3-0.3-3.4c-0.1-0.5,0.2-1.1,0.8-1.2c0.5-0.1,1.1,0.2,1.2,0.8c0.3,1.2,0.4,2.5,0.4,3.8
                        C48.3,36.7,42.8,43.5,36,43.5z" />
                    </g>
                    <g>
                      <path d="M17,58.8c-0.5,0-0.9-0.4-1-0.8c0-0.3-1-6.6,2.6-10.8c1.9-2.2,4.6-3.3,8.2-3.4c0.4-0.1,0.8,0,1,0.3c3,2,5.5,3.3,8.2,3.3
                        c2.7,0,5.2-1.3,8.4-3.4c0.4-0.3,0.9-0.2,1.2,0.1c0.3,0.3,0.4,0.8,0.2,1.2c-1.7,2.8-7.2,11.9-9.6,12.6c-2,0.6-5.2-3.5-9.7-12.1
                        c-2.8,0.1-4.9,1-6.3,2.7c-3,3.4-2.1,9.1-2.1,9.2c0.1,0.5-0.3,1.1-0.8,1.1C17.1,58.8,17.1,58.8,17,58.8z M29.7,47.6
                        c2.4,4.2,4.9,7.9,5.9,8.3c1-0.5,3.6-4.1,6.2-8.1c-2,1-3.8,1.6-5.8,1.6c0,0,0,0-0.1,0c0,0,0,0,0,0h0c0,0,0,0,0,0c0,0,0,0,0,0
                        C33.8,49.4,31.8,48.7,29.7,47.6z" />
                    </g>
                    <g>
                      <g id="XMLID_1_">
                        <g>
                          <path
                            fill="none"
                            stroke="#000000"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-miterlimit="10"
                            d="
                            M57.4,48l-5.5,11.4c-0.4,0.9-1.5,1.5-2.4,1.2c-1.2-0.4-1.8-1.7-1.3-2.8l5.5-11.5"
                          />

                          <path
                            fill="none"
                            stroke="#000000"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-miterlimit="10"
                            d="
                            M56.5,38.1l-1.9-1.6c-1.5-0.7-3.4-0.1-4.1,1.4l-1.6,3.4c-0.7,1.5-0.1,3.4,1.4,4.1l2.5,0.5l1,0.2h0l3.7,1.8l0,0l0.5,0.5l2,1.7
                            c1.5,0.7,3.4,0.1,4.1-1.4l1.6-3.4c0.7-1.5,0.1-3.4-1.4-4.1l-2.5-0.5L61,40.5l-3.6-1.8L56.5,38.1z"
                          />

                          <line
                            fill="none"
                            stroke="#000000"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-miterlimit="10"
                            x1="61.8"
                            y1="40.9"
                            x2="58.4"
                            y2="48"
                          />

                          <line
                            fill="none"
                            stroke="#000000"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-miterlimit="10"
                            x1="53"
                            y1="45.3"
                            x2="56.4"
                            y2="38.3"
                          />
                        </g>
                      </g>
                    </g>
                    <g>
                      <path
                        fill="none"
                        stroke="#000000"
                        stroke-width="2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-miterlimit="10"
                        d="
                        M27.4,58.7"
                      />
                    </g>
                    <g>
                      <path d="M32.2,54.4c-0.2,0-0.4-0.1-0.6-0.2c-0.4-0.3-0.5-1-0.2-1.4l3.8-5c0.2-0.3,0.5-0.4,0.8-0.4c0.3,0,0.6,0.2,0.8,0.4l3.4,4.8
                        c0.3,0.5,0.2,1.1-0.2,1.4c-0.5,0.3-1.1,0.2-1.4-0.2l-2.6-3.6L33,54C32.8,54.3,32.5,54.4,32.2,54.4z" />
                    </g>
                    <g>
                      <path d="M46.7,25.9c-0.1,0-0.2,0-0.3,0c-6.5-0.8-10.2-4-11.6-5.5c-3.4,2.7-6.5,3.8-8.1,4.3c-0.5,0.1-1.1-0.2-1.2-0.7
                        c-0.2-0.5,0.2-1.1,0.7-1.2c1.6-0.4,4.7-1.6,8.1-4.5c0.2-0.2,0.5-0.3,0.8-0.2c0.3,0,0.5,0.2,0.7,0.4c0,0,3.3,4.6,10.9,5.5
                        c0.2,0,0.3,0,0.4-0.1c0.5-0.7,0.2-3.2-1.4-5.8c-1.1-1.7-4.3-5.7-10.2-5c-8.3,0.9-9.8,5.8-10.1,7.3c-0.1,0.5-0.6,0.9-1.2,0.8
                        c-0.5-0.1-0.9-0.6-0.8-1.2c0.3-1.8,2.2-7.8,11.8-8.9c7.1-0.8,10.8,3.9,12.1,6c1.8,3,2.4,6.3,1.4,8C48.2,25.5,47.5,25.9,46.7,25.9z
                        " />
                    </g>
                    <g>
                      <path d="M25.1,35.2c-0.1,0-0.3,0-0.4,0c-0.5-0.1-0.9-0.6-0.8-1.2c0.1-0.5,0.6-0.9,1.2-0.8c0.4,0.1,1.1-0.5,1.3-1.1
                        c0.2-0.7-0.2-1.2-1.2-1.5c-1.8-0.6-2.8-1.6-3-2.8c-0.3-2.3,2.6-4.2,3.2-4.6l0.4-0.3c0.4-0.3,1.1-0.2,1.4,0.2
                        c0.3,0.4,0.2,1.1-0.2,1.4l-0.5,0.3c-1.1,0.7-2.4,2-2.4,2.7c0,0.4,0.6,0.8,1.6,1.1c2.4,0.8,2.9,2.5,2.5,3.9
                        C27.9,34,26.5,35.2,25.1,35.2z" />
                    </g>
                  </g>
                </svg>
                <%= gettext("Go to decision") %>: <%= if @current_interaction.story_result != -1,
                  do: @current_interaction.story_result,
                  else: "N/A" %>
                <code
                  :if={@show_shortcut}
                  class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
                >
                  n
                </code>
                <div :if={!@show_shortcut}></div>
              </ClaperWeb.Component.Input.page_button>
            </div>
          <% %Claper.Quizzes.Quiz{} -> %>
            <div class="grid grid-cols-1 space-y-1.5 items-center mt-1.5">
              <ClaperWeb.Component.Input.check_button
                key={:quiz_show_results}
                checked={@current_interaction.show_results}
                shortcut={if @create == nil, do: "Z", else: nil}
              >
                <svg
                  :if={@current_interaction.show_results}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4h1m4 0h13" /><path d="M4 4v10a2 2 0 0 0 2 2h10m3.42 -.592c.359 -.362 .58 -.859 .58 -1.408v-10" /><path d="M12 16v4" /><path d="M9 20h6" /><path d="M8 12l2 -2m4 0l2 -2" /><path d="M3 3l18 18" />
                </svg>

                <svg
                  :if={!@current_interaction.show_results}
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="h-6 w-6"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 4l18 0" /><path d="M4 4v10a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-10" /><path d="M12 16l0 4" /><path d="M9 20l6 0" /><path d="M8 12l3 -3l2 2l3 -3" />
                </svg>

                <span :if={@current_interaction.show_results}>
                  <%= gettext("Hide results on presentation") %>
                </span>
                <span :if={!@current_interaction.show_results}>
                  <%= gettext("Show results on presentation") %>
                </span>
                <code
                  :if={@show_shortcut}
                  class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
                >
                  z
                </code>
                <div :if={!@show_shortcut}></div>
              </ClaperWeb.Component.Input.check_button>
              <div>
                <ClaperWeb.Component.Input.check_button
                  disabled={!@current_interaction.show_results}
                  key={:review_quiz_questions}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    class="w-6 h-6"
                  >
                    <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 13a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M15 9a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M9 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v14a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M4 20h14" />
                  </svg>

                  <span>
                    <%= gettext("Review questions") %>
                  </span>
                  <div></div>
                </ClaperWeb.Component.Input.check_button>
              </div>
              <div class="grid grid-cols-2 gap-2">
                <ClaperWeb.Component.Input.check_button
                  disabled={!@current_interaction.show_results}
                  key={:prev_quiz_question}
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    class="w-6 h-6"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M11.78 5.22a.75.75 0 0 1 0 1.06L8.06 10l3.72 3.72a.75.75 0 1 1-1.06 1.06l-4.25-4.25a.75.75 0 0 1 0-1.06l4.25-4.25a.75.75 0 0 1 1.06 0Z"
                      clip-rule="evenodd"
                    />
                  </svg>

                  <span>
                    <%= gettext("Previous") %>
                  </span>
                </ClaperWeb.Component.Input.check_button>
                <ClaperWeb.Component.Input.check_button
                  disabled={!@current_interaction.show_results}
                  key={:next_quiz_question}
                >
                  <span>
                    <%= gettext("Next") %>
                  </span>
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    class="w-6 h-6"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M8.22 5.22a.75.75 0 0 1 1.06 0l4.25 4.25a.75.75 0 0 1 0 1.06l-4.25 4.25a.75.75 0 0 1-1.06-1.06L11.94 10 8.22 6.28a.75.75 0 0 1 0-1.06Z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </ClaperWeb.Component.Input.check_button>
              </div>
            </div>
          <% nil -> %>
            <p class="text-gray-400 italic mt-1.5">No interaction enabled</p>
          <% _ -> %>
            <p class="text-gray-400 italic mt-1.5">No settings available for this interaction</p>
        <% end %>

        <div class="flex space-x-2 items-center mt-3"></div>
      </div>
      <div class="grid grid-cols-1 space-y-5">
        <div class="grid grid-cols-1 space-y-1.5">
          <div class="flex items-center space-x-2 font-semibold text-lg">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path
                fill-rule="evenodd"
                d="M1 2.75A.75.75 0 0 1 1.75 2h16.5a.75.75 0 0 1 0 1.5H18v8.75A2.75 2.75 0 0 1 15.25 15h-1.072l.798 3.06a.75.75 0 0 1-1.452.38L13.41 18H6.59l-.114.44a.75.75 0 0 1-1.452-.38L5.823 15H4.75A2.75 2.75 0 0 1 2 12.25V3.5h-.25A.75.75 0 0 1 1 2.75ZM7.373 15l-.391 1.5h6.037l-.392-1.5H7.373ZM13.25 5a.75.75 0 0 1 .75.75v5.5a.75.75 0 0 1-1.5 0v-5.5a.75.75 0 0 1 .75-.75Zm-6.5 4a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-1.5 0v-1.5A.75.75 0 0 1 6.75 9Zm4-1.25a.75.75 0 0 0-1.5 0v3.5a.75.75 0 0 0 1.5 0v-3.5Z"
                clip-rule="evenodd"
              />
            </svg>

            <span><%= gettext("Presentation") %></span>
          </div>

          <div class="flex space-x-1 items-center mt-3">
            <ClaperWeb.Component.Input.check_button
              key={:join_screen_visible}
              checked={@state.join_screen_visible}
              shortcut={if @create == nil, do: "Q", else: nil}
            >
              <svg
                :if={!@state.join_screen_visible}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M4 4m0 1a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M7 17l0 .01" /><path d="M14 4m0 1a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M7 7l0 .01" /><path d="M4 14m0 1a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M17 7l0 .01" /><path d="M14 14l3 0" /><path d="M20 14l0 .01" /><path d="M14 14l0 3" /><path d="M14 20l3 0" /><path d="M17 17l3 0" /><path d="M20 17l0 3" />
              </svg>

              <svg
                :if={@state.join_screen_visible}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 4h1a1 1 0 0 1 1 1v1m-.297 3.711a1 1 0 0 1 -.703 .289h-4a1 1 0 0 1 -1 -1v-4c0 -.275 .11 -.524 .29 -.705" /><path d="M7 17v.01" /><path d="M14 4m0 1a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M7 7v.01" /><path d="M4 14m0 1a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1z" /><path d="M17 7v.01" /><path d="M20 14v.01" /><path d="M14 14v3" /><path d="M14 20h3" /><path d="M3 3l18 18" />
              </svg>
              <div>
                <span :if={!@state.join_screen_visible}>
                  <%= gettext("Show instructions to join") %>
                </span>
                <span :if={@state.join_screen_visible}>
                  <%= gettext("Hide instructions to join") %>
                </span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                q
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>

          <div class="flex space-x-2 items-center mt-3">
            <ClaperWeb.Component.Input.check_button
              key={:chat_visible}
              checked={@state.chat_visible}
              shortcut={if @create == nil, do: "W", else: nil}
            >
              <svg
                :if={!@state.chat_visible}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h8" /><path d="M8 13h6" /><path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12z" />
              </svg>
              <svg
                :if={@state.chat_visible}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h1m4 0h3" /><path d="M8 13h5" /><path d="M8 4h10a3 3 0 0 1 3 3v8c0 .577 -.163 1.116 -.445 1.573m-2.555 1.427h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8c0 -1.085 .576 -2.036 1.439 -2.562" /><path d="M3 3l18 18" />
              </svg>
              <div>
                <span :if={!@state.chat_visible}><%= gettext("Show messages") %></span>
                <span :if={@state.chat_visible}><%= gettext("Hide messages") %></span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                w
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>

          <div
            class={"#{if !@state.chat_visible, do: "opacity-50"} flex space-x-2 items-center mt-3"}
            title={
              if !@state.chat_visible,
                do: gettext("Show messages to change this option"),
                else: nil
            }
          >
            <ClaperWeb.Component.Input.check_button
              key={:show_only_pinned}
              checked={@state.show_only_pinned}
              disabled={!@state.chat_visible}
              shortcut={if @create == nil, do: "E", else: nil}
            >
              <svg
                :if={!@state.show_only_pinned}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h8" /><path d="M8 13h4.5" /><path d="M10.325 19.605l-2.325 1.395v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12a3 3 0 0 1 3 3v4.5" /><path d="M17.8 20.817l-2.172 1.138a.392 .392 0 0 1 -.568 -.41l.415 -2.411l-1.757 -1.707a.389 .389 0 0 1 .217 -.665l2.428 -.352l1.086 -2.193a.392 .392 0 0 1 .702 0l1.086 2.193l2.428 .352a.39 .39 0 0 1 .217 .665l-1.757 1.707l.414 2.41a.39 .39 0 0 1 -.567 .411l-2.172 -1.138z" />
              </svg>
              <svg
                :if={@state.show_only_pinned}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h8" /><path d="M8 13h6" /><path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12z" />
              </svg>
              <div>
                <span :if={!@state.show_only_pinned}>
                  <%= gettext("Show only pinned messages") %>
                </span>
                <span :if={@state.show_only_pinned}><%= gettext("Show all messages") %></span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                e
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>
        </div>

        <div class="grid grid-cols-1 space-y-1.5">
          <div class="flex items-center space-x-2 font-semibold text-lg">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 20 20"
              fill="currentColor"
              class="w-5 h-5"
            >
              <path d="M8 16.25a.75.75 0 0 1 .75-.75h2.5a.75.75 0 0 1 0 1.5h-2.5a.75.75 0 0 1-.75-.75Z" />
              <path
                fill-rule="evenodd"
                d="M4 4a3 3 0 0 1 3-3h6a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3V4Zm4-1.5v.75c0 .414.336.75.75.75h2.5a.75.75 0 0 0 .75-.75V2.5h1A1.5 1.5 0 0 1 14.5 4v12a1.5 1.5 0 0 1-1.5 1.5H7A1.5 1.5 0 0 1 5.5 16V4A1.5 1.5 0 0 1 7 2.5h1Z"
                clip-rule="evenodd"
              />
            </svg>

            <span><%= gettext("Attendees") %></span>
          </div>

          <div class="flex space-x-2 items-center mt-3">
            <ClaperWeb.Component.Input.check_button
              key={:chat_enabled}
              checked={@state.chat_enabled}
              shortcut={if @create == nil, do: "A", else: nil}
            >
              <svg
                :if={!@state.chat_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h8" /><path d="M8 13h6" /><path d="M18 4a3 3 0 0 1 3 3v8a3 3 0 0 1 -3 3h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8a3 3 0 0 1 3 -3h12z" />
              </svg>
              <svg
                :if={@state.chat_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M8 9h1m4 0h3" /><path d="M8 13h5" /><path d="M8 4h10a3 3 0 0 1 3 3v8c0 .577 -.163 1.116 -.445 1.573m-2.555 1.427h-5l-5 3v-3h-2a3 3 0 0 1 -3 -3v-8c0 -1.085 .576 -2.036 1.439 -2.562" /><path d="M3 3l18 18" />
              </svg>
              <div>
                <span :if={!@state.chat_enabled}><%= gettext("Enable messages") %></span>
                <span :if={@state.chat_enabled}><%= gettext("Disable messages") %></span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                a
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>

          <div
            class={"#{if !@state.chat_enabled, do: "opacity-50"} flex space-x-2 items-center mt-3"}
            title={
              if !@state.chat_enabled,
                do: gettext("Enable messages to change this option"),
                else: nil
            }
          >
            <ClaperWeb.Component.Input.check_button
              key={:anonymous_chat_enabled}
              checked={@state.anonymous_chat_enabled}
              disabled={!@state.chat_enabled}
              shortcut={if @create == nil, do: "S", else: nil}
            >
              <svg
                :if={!@state.anonymous_chat_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 11h18" /><path d="M5 11v-4a3 3 0 0 1 3 -3h8a3 3 0 0 1 3 3v4" /><path d="M7 17m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" /><path d="M17 17m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" /><path d="M10 17h4" />
              </svg>
              <svg
                :if={@state.anonymous_chat_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 11h8m4 0h6" /><path d="M5 11v-4c0 -.571 .16 -1.105 .437 -1.56m2.563 -1.44h8a3 3 0 0 1 3 3v4" /><path d="M7 17m-3 0a3 3 0 1 0 6 0a3 3 0 1 0 -6 0" /><path d="M14.88 14.877a3 3 0 1 0 4.239 4.247m.59 -3.414a3.012 3.012 0 0 0 -1.425 -1.422" /><path d="M10 17h4" /><path d="M3 3l18 18" />
              </svg>

              <div>
                <span :if={!@state.anonymous_chat_enabled}>
                  <%= gettext("Allow anonymous messages") %>
                </span>
                <span :if={@state.anonymous_chat_enabled}>
                  <%= gettext("Deny anonymous messages") %>
                </span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                s
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>

          <div class="flex space-x-2 items-center mt-3">
            <ClaperWeb.Component.Input.check_button
              key={:message_reaction_enabled}
              checked={@state.message_reaction_enabled}
              shortcut={if @create == nil, do: "D", else: nil}
            >
              <svg
                :if={!@state.message_reaction_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M19.5 12.572l-7.5 7.428l-7.5 -7.428a5 5 0 1 1 7.5 -6.566a5 5 0 1 1 7.5 6.572" />
              </svg>
              <svg
                :if={@state.message_reaction_enabled}
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="w-5 h-5"
              >
                <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 3l18 18" /><path d="M19.5 12.572l-1.5 1.428m-2 2l-4 4l-7.5 -7.428a5 5 0 0 1 -1.288 -5.068a4.976 4.976 0 0 1 1.788 -2.504m3 -1c1.56 0 3.05 .727 4 2a5 5 0 1 1 7.5 6.572" />
              </svg>

              <div>
                <span :if={!@state.message_reaction_enabled}>
                  <%= gettext("Enable reactions") %>
                </span>
                <span :if={@state.message_reaction_enabled}>
                  <%= gettext("Disable reactions") %>
                </span>
              </div>
              <code
                :if={@show_shortcut}
                class="px-2 py-1.5 text-xs font-semibold text-gray-800 bg-gray-100 border border-gray-200 rounded-lg"
              >
                d
              </code>
              <div :if={!@show_shortcut}></div>
            </ClaperWeb.Component.Input.check_button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
