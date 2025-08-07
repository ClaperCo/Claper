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
            <div class="relative">
              {password_input(
                @form,
                @field,
                [
                  class: "input w-full pr-10",
                  placeholder: @placeholder,
                  required: @required,
                  id: "password-field-#{@field}"
                ] ++ @extra_attrs
              )}
              <button
                type="button"
                class="absolute inset-y-0 right-0 pr-3 flex items-center text-base-content/50 hover:text-base-content"
                phx-click={toggle_password_visibility("password-field-#{@field}")}
              >
                <i class="fas fa-eye"></i>
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
            <span class="label-text-alt">{@description}</span>
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
    %Phoenix.LiveView.JS{}
    |> Phoenix.LiveView.JS.dispatch("toggle-password", to: "##{field_id}")
  end
end
