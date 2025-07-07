defmodule ClaperWeb.Component.Alert do
  use ClaperWeb, :view_component

  def info(assigns) do
    assigns =
      assigns
      |> assign_new(:stick, fn -> false end)

    ~H"""
    <div
      class="bg-supporting-green-50 border-t-4 rounded-b-md shadow-md border-supporting-green-400 p-4 mb-3"
      x-data="{ open: true }"
      x-show={if @stick, do: "true", else: "open"}
      x-init="setTimeout(() => {open = false},  4000)"
      x-transition
    >
      <div class="flex">
        <div class="shrink-0">
          <svg
            class="h-5 w-5 text-green-400"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-supporting-green-700">
            {@message}
          </p>
        </div>
      </div>
    </div>
    """
  end

  def error(assigns) do
    assigns =
      assigns
      |> assign_new(:stick, fn -> false end)

    ~H"""
    <div
      class="bg-supporting-red-50 border-t-4 rounded-b-md shadow-md border-supporting-red-400 p-4 mb-3"
      x-data="{ open: true }"
      x-show={if @stick, do: "true", else: "open"}
      x-init="setTimeout(() => {open = false},  4000)"
      x-transition
    >
      <div class="flex">
        <div class="shrink-0">
          <!-- Heroicon name: solid/exclamation -->
          <svg
            class="h-5 w-5 text-supporting-red-400"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 20 20"
            fill="currentColor"
            aria-hidden="true"
          >
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
              clip-rule="evenodd"
            />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-supporting-red-700">
            {@message}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
