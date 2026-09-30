defmodule ClaperWeb.Component.Alert do
  use ClaperWeb, :view_component

  def info(assigns) do
    alert(assign(assigns, :kind, :info))
  end

  def error(assigns) do
    alert(assign(assigns, :kind, :error))
  end

  defp alert(assigns) do
    assigns = assign_new(assigns, :stick, fn -> false end)

    ~H"""
    <div
      class={[
        "alert shadow-lg",
        @kind == :info && "alert-success text-white",
        @kind == :error && "alert-error"
      ]}
      data-auto-dismiss-alert={if @stick, do: nil, else: "true"}
      role="alert"
    >
      <div class="flex items-center gap-3">
        <div class="shrink-0">
          <svg
            :if={@kind == :info}
            class="h-5 w-5"
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
          <svg
            :if={@kind == :error}
            class="h-5 w-5"
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
        <span>{@message}</span>
      </div>
    </div>
    """
  end
end
