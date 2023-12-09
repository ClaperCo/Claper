defmodule ClaperWeb.EventLive.FormComponent do
  use ClaperWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div
        id="collapsed-form"
        class="bg-black py-3 px-6 text-black shadow-lg mx-auto rounded-full w-max hidden"
      >
        <div class="block w-full h-full cursor-pointer" phx-click={toggle_form()} phx-target={@myself}>
          <div class="text-white flex space-x-2 items-center">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-6 w-6"
              viewBox="0 0 24 24"
              stroke-width="1.5"
              stroke="currentColor"
              fill="none"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <path stroke="none" d="M0 0h24v24H0z" fill="none"></path>
              <path d="M12 3a3 3 0 0 0 -3 3v12a3 3 0 0 0 3 3"></path>
              <path d="M6 3a3 3 0 0 1 3 3v12a3 3 0 0 1 -3 3"></path>
              <path d="M13 7h7a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-7"></path>
              <path d="M5 7h-1a1 1 0 0 0 -1 1v8a1 1 0 0 0 1 1h1"></path>
              <path d="M17 12h.01"></path>
              <path d="M13 12h.01"></path>
            </svg>
            <span class="font-bold"><%= gettext("See current form") %></span>
          </div>
        </div>
      </div>
      <div id="extended-form" class="bg-black w-full py-3 px-6 text-black shadow-lg rounded-md">
        <div class="block w-full h-full cursor-pointer" phx-click={toggle_form()} phx-target={@myself}>
          <div id="form-pane" class="float-right mt-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-8 w-8 text-white"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="2"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </div>

          <p class="text-xs text-gray-500 my-1"><%= gettext("Current form") %></p>
          <p class="text-white text-lg font-semibold mb-4"><%= @form.title %></p>
        </div>
        <%= form_for :form_submit, "#", [id: @id, phx_change: "validate", phx_target: @myself, phx_submit: "submit"], fn f -> %>
          <div class="flex flex-col space-y-3">
            <%= if (length @form.fields) > 0 do %>
              <%= for field <- @form.fields do %>
                <%= case field.type do %>
                  <% "text" -> %>
                    <ClaperWeb.Component.Input.text
                      form={f}
                      labelClass="text-white"
                      fieldClass="bg-gray-700 text-white"
                      key={String.to_atom(field.name)}
                      name={field.name}
                      required="true"
                      value={
                        if is_nil(assigns.current_form_submit),
                          do: ~c"",
                          else: assigns.current_form_submit.response[field.name]
                      }
                    />
                  <% "email" -> %>
                    <ClaperWeb.Component.Input.email
                      form={f}
                      labelClass="text-white"
                      fieldClass="bg-gray-700 text-white"
                      key={String.to_atom(field.name)}
                      name={field.name}
                      required="true"
                      value={
                        if is_nil(assigns.current_form_submit),
                          do: ~c"",
                          else: assigns.current_form_submit.response[field.name]
                      }
                    />
                <% end %>
              <% end %>
            <% end %>
          </div>

          <div class="flex items-center gap-4">
            <button
              type="submit"
              class="px-3 py-2 text-white font-semibold bg-primary-500 hover:bg-primary-600 rounded-md my-5"
            >
              <%= if is_nil(assigns.current_form_submit), do: gettext("Submit"), else: gettext("Edit") %>
            </button>

            <%= unless is_nil(assigns.current_form_submit) do %>
              <div class="flex gap-1 text-green-500 text-sm">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-6 w-6"
                  viewBox="0 0 24 24"
                  stroke-width="2"
                  stroke="currentColor"
                  fill="none"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0" /><path d="M9 12l2 2l4 -4" />
                </svg>
                <span><%= gettext("Saved") %></span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"form_submit" => form_submit_params}, socket) do
    changeset =
      (socket.assigns.current_form_submit || %Claper.Forms.FormSubmit{})
      |> Claper.Forms.change_form_submit(form_submit_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event(
        "submit",
        %{"form_submit" => params},
        %{assigns: %{current_user: current_user}} = socket
      )
      when is_map(current_user) do
    case Claper.Forms.create_or_update_form_submit(
           socket.assigns.event.uuid,
           %{"response" => params}
           |> Map.put("user_id", socket.assigns.current_user.id)
           |> Map.put("form_id", socket.assigns.form.id)
         ) do
      {:ok, form_submit} ->
        {:noreply,
         socket
         |> assign(:current_form_submit, form_submit)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event(
        "submit",
        %{"form_submit" => params},
        %{assigns: %{attendee_identifier: attendee_identifier}} = socket
      ) do
    case Claper.Forms.create_or_update_form_submit(
           socket.assigns.event.uuid,
           %{"response" => params}
           |> Map.put("attendee_identifier", attendee_identifier)
           |> Map.put("form_id", socket.assigns.form.id)
         ) do
      {:ok, form_submit} ->
        {:noreply,
         socket
         |> assign(:current_form_submit, form_submit)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def toggle_form(js \\ %JS{}) do
    js
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#collapsed-form",
      time: 50
    )
    |> JS.toggle(
      out: "animate__animated animate__zoomOut",
      in: "animate__animated animate__zoomIn",
      to: "#extended-form"
    )
  end
end
