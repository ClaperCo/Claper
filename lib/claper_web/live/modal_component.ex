defmodule ClaperWeb.ModalComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      class="absolute z-10 inset-0 overflow-y-auto phx-modal pt-24"
      aria-labelledby="modal-title"
      role="dialog"
      aria-modal="true"
      id="modal"
      phx-remove={hide_modal()}
      phx-click-away={hide_modal()}
      phx-window-keydown={hide_modal()}
      phx-key="escape"
      phx-target={@myself}
    >
      <div class="flex items-center justify-center pt-4 px-4 pb-20 text-center sm:block sm:p-4">
        <div
          class="fixed inset-0 bg-gray-500/75 transition-opacity -z-10"
          phx-click={hide_modal()}
          phx-target={@myself}
          aria-hidden="true"
        >
        </div>

        <div class="inline-block align-middle bg-white rounded-lg px-4 pt-5 pb-4 text-left overflow-hidden shadow-xl transform transition-all relative">
          <div
            class="text-2xl text-gray-400 absolute right-5 top-3 cursor-pointer"
            phx-click={hide_modal()}
            phx-target={@myself}
          >
            &times;
          </div>

          <h3 class="text-lg leading-6 font-medium text-gray-900">
            {@title}
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500">
            <p>
              {@description}
            </p>
          </div>
          <div class="mt-2">
            <p class="text-sm text-gray-500">
              {render_slot(@inner_block)}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("hide", _, socket) do
    {:noreply,
     socket
     |> push_patch(to: socket.assigns.return_to)}
  end

  def hide_modal(js \\ %JS{}) do
    js
    |> JS.hide(to: "#modal", transition: "animate__animated animate__fadeOut", time: 300)
    |> JS.push("hide", target: "#modal", page_loading: true)
  end
end
