defmodule ClaperWeb.AdminLive.OidcProviderLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts.Oidc

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="provider-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-6 gap-6">
          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="name-field"
            form={@form}
            field={:name}
            type="text"
            label="Name"
            placeholder="Enter provider name"
            required={true}
            width_class="sm:col-span-6"
            description="A unique name to identify this OIDC provider"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="issuer-field"
            form={@form}
            field={:issuer}
            type="text"
            label="Issuer URL"
            placeholder="https://example.com"
            required={true}
            width_class="sm:col-span-6"
            description="The OIDC issuer URL (must start with http:// or https://)"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="client_id-field"
            form={@form}
            field={:client_id}
            type="text"
            label="Client ID"
            placeholder="Enter client ID"
            required={true}
            width_class="sm:col-span-3"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="client_secret-field"
            form={@form}
            field={:client_secret}
            type="password"
            label="Client Secret"
            placeholder="Enter client secret"
            required={true}
            width_class="sm:col-span-3"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="redirect_uri-field"
            form={@form}
            field={:redirect_uri}
            type="text"
            label="Redirect URI"
            placeholder="https://yourapp.com/auth/callback"
            required={true}
            width_class="sm:col-span-6"
            description="The callback URL for your application (must start with http:// or https://)"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="scope-field"
            form={@form}
            field={:scope}
            type="text"
            label="Scope"
            placeholder="openid email profile"
            width_class="sm:col-span-3"
            description="OIDC scopes to request (defaults to 'openid email profile')"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="response_type-field"
            form={@form}
            field={:response_type}
            type="select"
            label="Response Type"
            select_options={[{"Authorization Code", "code"}, {"Implicit", "token"}, {"Hybrid", "code token"}]}
            width_class="sm:col-span-3"
            description="OAuth 2.0 response type (defaults to 'code')"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="response_mode-field"
            form={@form}
            field={:response_mode}
            type="select"
            label="Response Mode"
            select_options={[{"Query", "query"}, {"Fragment", "fragment"}, {"Form Post", "form_post"}]}
            width_class="sm:col-span-3"
            description="How the authorization response should be returned (defaults to 'query')"
          />

          <.live_component
            module={ClaperWeb.AdminLive.FormFieldComponent}
            id="active-field"
            form={@form}
            field={:active}
            type="checkbox"
            label="Active"
            checkbox_label="Enable this OIDC provider"
            width_class="sm:col-span-3"
            description="Whether this provider is currently active and available for authentication"
          />
        </div>

        <div class="pt-6">
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="bg-white py-2 px-4 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Cancel
            </button>
            <button
              type="submit"
              phx-disable-with="Saving..."
              class="ml-3 inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <%= if @action == :new, do: "Create Provider", else: "Update Provider" %>
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{provider: provider} = assigns, socket) do
    changeset = Oidc.change_provider(provider)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"provider" => provider_params}, socket) do
    changeset =
      socket.assigns.provider
      |> Oidc.change_provider(provider_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.action, provider_params)
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: socket.assigns.navigate)}
  end

  defp save_provider(socket, :edit, provider_params) do
    case Oidc.update_provider(socket.assigns.provider, provider_params) do
      {:ok, provider} ->
        notify_parent({:saved, provider})

        {:noreply,
         socket
         |> put_flash(:info, "Provider updated successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_provider(socket, :new, provider_params) do
    case Oidc.create_provider(provider_params) do
      {:ok, provider} ->
        notify_parent({:saved, provider})

        {:noreply,
         socket
         |> put_flash(:info, "Provider created successfully")
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end