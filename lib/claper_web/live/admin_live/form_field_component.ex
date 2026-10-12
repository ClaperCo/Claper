defmodule ClaperWeb.AdminLive.FormFieldComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={if @width_class, do: @width_class, else: "sm:col-span-6"}>
      <div class="form-control w-full">
        <label class="label">
          <span class="label-text">{@label}</span>
        </label>
        <%= case @type do %>
          <% "text" -> %>
            {text_input(
              @form,
              @field,
              [
                class: "input w-full " <> @field_class,
                placeholder: @placeholder,
                required: @required
              ] ++ @extra_attrs
            )}
          <% "email" -> %>
            {email_input(
              @form,
              @field,
              [
                class: "input w-full",
                placeholder: @placeholder,
                required: @required
              ] ++ @extra_attrs
            )}
          <% "password" -> %>
            <%!-- Only the submitted value is echoed back, so a re-render keeps what
                  was typed without ever sending a stored secret to the browser. --%>
            <div class="relative">
              {password_input(
                @form,
                @field,
                [
                  class: "input w-full pr-10",
                  placeholder: @placeholder,
                  required: @required,
                  id: "password-field-#{@field}",
                  value: @form.params[to_string(@field)]
                ] ++ @extra_attrs
              )}
              <button
                type="button"
                class="absolute inset-y-0 right-0 z-10 pr-3 flex items-center text-base-content/50 hover:text-base-content"
                phx-click={toggle_password_visibility("password-field-#{@field}")}
                aria-label={gettext("Show or hide")}
                title={gettext("Show or hide")}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="w-5 h-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z"
                  />
                </svg>
              </button>
            </div>
          <% "textarea" -> %>
            {textarea(
              @form,
              @field,
              [
                class: "input w-full",
                placeholder: @placeholder,
                required: @required,
                rows: @rows
              ] ++ @extra_attrs
            )}
          <% "select" -> %>
            {select(
              @form,
              @field,
              @select_options,
              [
                class: "select w-full",
                prompt: @prompt || gettext("Select an option"),
                required: @required
              ] ++ @extra_attrs
            )}
          <% "checkbox" -> %>
            <div class="form-control">
              <label class="label cursor-pointer justify-start">
                {checkbox(
                  @form,
                  @field,
                  [
                    class: "checkbox checkbox-primary",
                    checked:
                      Phoenix.HTML.Form.input_value(@form, @field) == true ||
                        Phoenix.HTML.Form.input_value(@form, @field) == "true"
                  ] ++ @extra_attrs
                )}
                <span class="label-text ml-2">{@checkbox_label || @label}</span>
              </label>
            </div>
          <% "date" -> %>
            {date_input(
              @form,
              @field,
              [
                class: "input input-bordered w-full",
                required: @required
              ] ++ @extra_attrs
            )}
          <% "datetime" -> %>
            {datetime_local_input(
              @form,
              @field,
              [
                class: "input input-bordered w-full",
                required: @required
              ] ++ @extra_attrs
            )}
          <% "file" -> %>
            <div class="flex items-center gap-3">
              <label class="btn btn-outline btn-sm">
                <span>{gettext("Choose file")}</span>
                {file_input(
                  @form,
                  @field,
                  [
                    class: "sr-only",
                    required: @required,
                    phx_change: "file_selected",
                    phx_target: @myself
                  ] ++ @extra_attrs
                )}
              </label>
              <span class="text-sm text-base-content/70" id={"file-name-#{@field}"}>
                {if @selected_file, do: @selected_file, else: gettext("No file chosen")}
              </span>
            </div>
          <% _ -> %>
            {text_input(
              @form,
              @field,
              [
                class: "input input-bordered w-full",
                placeholder: @placeholder,
                required: @required
              ] ++ @extra_attrs
            )}
        <% end %>

        <label class="label">
          {error_tag(@form, @field)}
          <%= if @description do %>
            <span class="label-text-alt whitespace-normal">{@description}</span>
          <% end %>
        </label>
      </div>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, assign(socket, selected_file: nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:placeholder, fn -> "" end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:description, fn -> nil end)
      |> assign_new(:width_class, fn -> nil end)
      |> assign_new(:field_class, fn -> "" end)
      |> assign_new(:checkbox_label, fn -> nil end)
      |> assign_new(:prompt, fn -> nil end)
      |> assign_new(:select_options, fn -> [] end)
      |> assign_new(:rows, fn -> 3 end)
      |> assign_new(:extra_attrs, fn -> [] end)

    {:ok, socket}
  end

  @impl true
  def handle_event("file_selected", %{"_target" => [_field_name]}, socket) do
    {:noreply, assign(socket, selected_file: gettext("File selected"))}
  end

  defp toggle_password_visibility(field_id) do
    JS.toggle_attribute({"type", "text", "password"}, to: "##{field_id}")
  end
end
