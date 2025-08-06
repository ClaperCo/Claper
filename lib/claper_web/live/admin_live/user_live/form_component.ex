defmodule ClaperWeb.AdminLive.UserLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form for={@form} id="user-form" phx-target={@myself} phx-change="validate" phx-submit="save">
        <div class="grid grid-cols-6 gap-6">
          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="user-email"
            form={@form}
            field={:email}
            type="email"
            label="Email"
            placeholder="Enter user email"
            required={true}
            width_class="sm:col-span-6"
            description="User's email address (must be unique)"
          />

          <%= if @action == :new do %>
            <.live_component
              module={ClaperWeb.AdminLive.FormFieldComponent}
              id="user-password"
              form={@form}
              field={:password}
              type="password"
              label="Password"
              placeholder="Enter password"
              required={true}
              width_class="sm:col-span-3"
              description="Initial password for the user"
            />
          <% end %>

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="user-role-id"
            form={@form}
            field={:role_id}
            type="select"
            label="Role"
            select_options={@role_options}
            required={true}
            width_class="sm:col-span-3"
            description="User's access level"
          />

          <div class="sm:col-span-6">
            <div class="form-control">
              <label class="label">
                <span class="label-text">Account Status</span>
              </label>
              <label class="label cursor-pointer justify-start">
                <input
                  type="checkbox"
                  name="user[confirmed]"
                  value="true"
                  checked={@confirmed_checked}
                  class="checkbox checkbox-primary"
                />
                <span class="label-text ml-2">Account is confirmed and active</span>
              </label>
              <label class="label">
                <span class="label-text-alt">
                  {if @action == :new, do: "Check to create an already confirmed account", else: "Whether the user's email has been confirmed"}
                </span>
              </label>
            </div>
          </div>
        </div>

        <div class="pt-6">
          <div class="flex justify-end gap-3">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
              {if @action == :new, do: "Create User", else: "Update User"}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)

    role_options =
      Accounts.list_roles()
      |> Enum.map(&{String.capitalize(&1.name), &1.id})
    
    # Determine if confirmed checkbox should be checked
    confirmed_checked = 
      case assigns.action do
        :edit -> !is_nil(user.confirmed_at)
        :new -> false
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:role_options, role_options)
     |> assign(:confirmed_checked, confirmed_checked)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    # Update the confirmed_checked state based on form params
    confirmed_checked = Map.get(user_params, "confirmed") == "true"
    
    # Convert confirmed checkbox to confirmed_at datetime
    user_params = maybe_convert_confirmed_field(user_params)

    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, 
     socket
     |> assign(:confirmed_checked, confirmed_checked)
     |> assign_form(changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    # Convert confirmed checkbox to confirmed_at datetime
    user_params = maybe_convert_confirmed_field(user_params)
    save_user(socket, socket.assigns.action, user_params)
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.navigate)}
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        notify_parent({:saved, user})

        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: :user)
    assign(socket, :form, form)
  end

  defp maybe_convert_confirmed_field(user_params) do
    case Map.get(user_params, "confirmed") do
      "true" ->
        user_params
        |> Map.delete("confirmed")
        |> Map.put("confirmed_at", NaiveDateTime.utc_now())

      "false" ->
        user_params
        |> Map.delete("confirmed")
        |> Map.put("confirmed_at", nil)

      _ ->
        user_params
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
