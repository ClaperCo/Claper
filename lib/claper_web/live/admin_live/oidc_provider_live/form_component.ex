defmodule ClaperWeb.AdminLive.OidcProviderLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider
  alias ClaperWeb.Validators.AdminFormValidator
  alias ClaperWeb.Component.Input

  @impl true
  def update(%{provider: provider} = assigns, socket) do
    changeset = Oidc.change_provider(provider)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate", %{"provider" => provider_params}, socket) do
    changeset =
      socket.assigns.provider
      |> Oidc.change_provider(provider_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.action, provider_params)
  end

  defp save_provider(socket, :edit, provider_params) do
    case Oidc.update_provider(socket.assigns.provider, provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "OIDC provider updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "provider")
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp save_provider(socket, :new, provider_params) do
    case Oidc.create_provider(provider_params) do
      {:ok, _provider} ->
        {:noreply,
         socket
         |> put_flash(:info, "OIDC provider created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Add validation errors to the changeset
        changeset = AdminFormValidator.add_validation_errors(changeset, "provider")
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
          Edit OIDC provider details
        <% else %>
          Create a new OIDC provider
        <% end %>
      </p>

      <%= form_for @changeset, "#",
        [id: "provider-form", phx_target: @myself, phx_change: "validate", phx_submit: "save"], fn form -> %>
        <div class="space-y-6">
          <Input.text form={form} key={:name} name="Name" required={true} />
          <Input.text form={form} key={:issuer} name="Issuer" required={true} />
          <Input.text form={form} key={:client_id} name="Client ID" required={true} />
          <Input.password form={form} key={:client_secret} name="Client Secret" required={true} />
          <Input.text form={form} key={:response_type} name="Response Type" value="code" />
          <Input.text form={form} key={:scope} name="Scope" value="openid email profile" />
          
          <div class="flex items-center space-x-2">
            <label for="provider_active" class="text-sm font-medium text-gray-700">Active</label>
            <%= checkbox(form, :active, class: "h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded") %>
          </div>
          
          <div class="flex justify-end mt-6">
            <button type="submit" phx-disable-with="Saving..." class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Save Provider
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
