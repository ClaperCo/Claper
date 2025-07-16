defmodule ClaperWeb.AdminLive.UserLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts
  alias Claper.Accounts.User
  alias ClaperWeb.Validators.AdminFormValidator
  alias ClaperWeb.Component.Input

  @impl true
  def update(%{user: user} = assigns, socket) do
    changeset = Accounts.change_user(user)
    roles = Accounts.list_roles()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:roles, roles)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      socket.assigns.user
      |> Accounts.change_user(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    save_user(socket, socket.assigns.action, user_params)
  end

  defp save_user(socket, :edit, user_params) do
    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "user")
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_user(socket, :new, user_params) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "user")
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h2 class="text-2xl font-bold mb-2"><%= @title %></h2>
      <p class="text-gray-600 mb-6">
        <%= if @action == :edit do %>
          Edit user details
        <% else %>
          Create a new user
        <% end %>
      </p>

      <%= form_for @changeset, "#",
        [id: "user-form", phx_target: @myself, phx_change: "validate", phx_submit: "save"], fn form -> %>
        <div class="space-y-6">
          <Input.email form={form} key={:email} name="Email" required={true} />
          
          <%= if @action == :new do %>
            <div class="space-y-4">
              <Input.password form={form} key={:password} name="Password" required={true} />
              <Input.password form={form} key={:password_confirmation} name="Confirm password" required={true} />
            </div>
          <% end %>
          
          <div class="relative">
            <label for="user_role_id" class="block text-sm font-medium text-gray-700">Role</label>
            <div class="mt-1">
              <%= select(form, :role_id, Enum.map(@roles, &{&1.name, &1.id}), 
                class: "bg-white outline-hidden shadow-base focus:ring-primary-500 focus:border-primary-500 block w-full text-lg border-gray-300 rounded-md py-2 px-3") %>
            </div>
            <%= if Keyword.has_key?(form.errors, :role_id) do %>
              <p class="text-supporting-red-500 text-sm"><%= error_tag(form, :role_id) %></p>
            <% end %>
          </div>
          
          <Input.date form={form} key={:confirmed_at} name="Confirmed at" />
          
          <div class="flex items-center space-x-2">
            <label for="user_is_active" class="text-sm font-medium text-gray-700">Active</label>
            <%= checkbox(form, :is_active, class: "h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded") %>
          </div>
          
          <div class="flex justify-end mt-6">
            <button type="submit" phx-disable-with="Saving..." class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Save User
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
