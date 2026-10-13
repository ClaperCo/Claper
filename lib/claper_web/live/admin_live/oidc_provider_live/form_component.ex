defmodule ClaperWeb.AdminLive.OidcProviderLive.FormComponent do
  use ClaperWeb, :live_component

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider
  alias ClaperWeb.UserOidcAuth

  @default_logo "/images/icons/openid.png"

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
        <div class="space-y-10">
          <section>
            <.section_header title={gettext("General")} />
            <div class="grid grid-cols-6 gap-6">
              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="name-field"
                form={@form}
                field={:name}
                type="text"
                label={gettext("Name")}
                placeholder={gettext("Enter provider name")}
                required={true}
                width_class="sm:col-span-6"
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="slug-field"
                form={@form}
                field={:slug}
                type="text"
                label={gettext("Slug")}
                placeholder="google"
                width_class="sm:col-span-3"
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="position-field"
                form={@form}
                field={:position}
                type="text"
                label={gettext("Position")}
                placeholder="0"
                width_class="sm:col-span-3"
                extra_attrs={[type: "number", min: 0, step: 1]}
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="active-field"
                form={@form}
                field={:active}
                type="checkbox"
                label={gettext("Active")}
                checkbox_label={gettext("Enable this OIDC provider")}
                width_class="sm:col-span-6"
              />
            </div>
          </section>

          <section>
            <.section_header title={gettext("Connection")} />
            <div class="grid grid-cols-6 gap-6">
              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="issuer-field"
                form={@form}
                field={:issuer}
                type="text"
                label={gettext("Issuer URL")}
                placeholder="https://accounts.google.com"
                required={true}
                width_class="sm:col-span-6"
                extra_attrs={[type: "url", autocomplete: "off"]}
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="client_id-field"
                form={@form}
                field={:client_id}
                type="text"
                label={gettext("Client ID")}
                placeholder={gettext("Enter client ID")}
                required={true}
                width_class="sm:col-span-3"
                extra_attrs={[autocomplete: "off"]}
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="client_secret-field"
                form={@form}
                field={:client_secret}
                type="password"
                label={gettext("Client Secret")}
                placeholder={
                  if @secret_stored?,
                    do: gettext("Leave blank to keep the current secret"),
                    else: gettext("Enter client secret")
                }
                required={!@secret_stored?}
                width_class="sm:col-span-3"
                extra_attrs={[autocomplete: "new-password"]}
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="scope-field"
                form={@form}
                field={:scope}
                type="text"
                label={gettext("Scope")}
                placeholder="openid email profile"
                width_class="sm:col-span-6"
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="redirect_uri-field"
                form={@form}
                field={:redirect_uri}
                type="text"
                label={gettext("Redirect URI")}
                placeholder={UserOidcAuth.callback_url("google")}
                required={true}
                width_class="sm:col-span-6"
                extra_attrs={[type: "url", autocomplete: "off"]}
                description={gettext("Register this URL at your provider")}
              />
            </div>
          </section>

          <section>
            <.section_header title={gettext("Login button")} />
            <div class="grid grid-cols-6 gap-6">
              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="logo_url-field"
                form={@form}
                field={:logo_url}
                type="text"
                label={gettext("Logo URL")}
                placeholder={@default_logo}
                extra_attrs={[phx_debounce: "500"]}
                width_class="sm:col-span-6"
              />

              <div class="sm:col-span-6">
                <span class="label-text">{gettext("Preview")}</span>
                <div class="mt-2 flex">
                  <span
                    id="provider-button-preview"
                    class="flex items-center gap-x-2 rounded-xl border border-base-300 px-4 py-3 text-sm font-medium"
                  >
                    <img width="24" src={@logo_preview} alt="" />
                    <span>{gettext("Log in with %{provider}", provider: @name_preview)}</span>
                  </span>
                </div>
              </div>
            </div>
          </section>

          <section>
            <.section_header title={gettext("Advanced")} />
            <div class="grid grid-cols-6 gap-6">
              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="response_type-field"
                form={@form}
                field={:response_type}
                type="select"
                label={gettext("Response Type")}
                select_options={[
                  {gettext("Authorization Code"), "code"},
                  {gettext("Implicit"), "token"},
                  {gettext("Hybrid"), "code token"}
                ]}
                width_class="sm:col-span-3"
              />

              <.live_component
                module={ClaperWeb.AdminLive.FormFieldComponent}
                id="response_mode-field"
                form={@form}
                field={:response_mode}
                type="select"
                label={gettext("Response Mode")}
                select_options={[
                  {gettext("Query"), "query"},
                  {gettext("Fragment"), "fragment"},
                  {gettext("Form Post"), "form_post"}
                ]}
                width_class="sm:col-span-3"
              />
            </div>
          </section>
        </div>

        <div class="pt-6">
          <div class="flex justify-end gap-3">
            <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
              {gettext("Cancel")}
            </button>
            <button type="submit" phx-disable-with={gettext("Saving...")} class="btn btn-primary">
              {if @action == :new, do: gettext("Create Provider"), else: gettext("Update Provider")}
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  attr :title, :string, required: true

  defp section_header(assigns) do
    ~H"""
    <h2 class="mb-4 border-b border-base-300 pb-2 text-lg font-semibold">{@title}</h2>
    """
  end

  @impl true
  def update(%{provider: provider} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:default_logo, @default_logo)
     |> assign(:secret_stored?, present?(provider.client_secret))
     |> assign(:slug_auto?, not present?(provider.slug))
     |> assign(:redirect_uri_auto?, redirect_uri_auto?(provider))
     |> assign_form(Oidc.change_provider(provider))}
  end

  @impl true
  def handle_event("validate", %{"provider" => provider_params} = params, socket) do
    socket =
      socket
      |> track_slug(params["_target"], provider_params)
      |> track_redirect_uri(params["_target"], provider_params)

    changeset =
      socket.assigns.provider
      |> Oidc.change_provider(prepare_params(socket, provider_params))
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"provider" => provider_params}, socket) do
    save_provider(socket, socket.assigns.action, prepare_params(socket, provider_params))
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
         |> put_flash(:info, gettext("Provider updated successfully"))
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
         |> put_flash(:info, gettext("Provider created successfully"))
         |> push_navigate(to: socket.assigns.navigate)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  # A new provider's slug follows its name until the slug field is typed in;
  # clearing the field attaches it again. A stored slug never follows the name,
  # as renaming a provider must not move the callback registered at the IdP.
  defp track_slug(socket, ["provider", "slug"], provider_params) do
    assign(socket, :slug_auto?, not present?(provider_params["slug"]))
  end

  defp track_slug(socket, _target, _provider_params), do: socket

  # The redirect URI follows the slug while it still holds the derived value.
  # Typing in the field detaches it; clearing the field attaches it again.
  defp redirect_uri_auto?(%Provider{redirect_uri: redirect_uri, slug: slug}) do
    not present?(redirect_uri) or redirect_uri == UserOidcAuth.callback_url(slug)
  end

  defp track_redirect_uri(socket, ["provider", "redirect_uri"], provider_params) do
    assign(socket, :redirect_uri_auto?, not present?(provider_params["redirect_uri"]))
  end

  defp track_redirect_uri(socket, _target, _provider_params), do: socket

  defp prepare_params(socket, provider_params) do
    provider_params
    |> keep_stored_secret(socket.assigns.secret_stored?)
    |> put_derived_slug(socket.assigns.slug_auto?)
    |> put_derived_redirect_uri(socket.assigns.redirect_uri_auto?)
  end

  # The stored secret is never sent to the browser, so a blank field means
  # "unchanged" rather than "erase".
  defp keep_stored_secret(provider_params, true) do
    if present?(provider_params["client_secret"]),
      do: provider_params,
      else: Map.delete(provider_params, "client_secret")
  end

  defp keep_stored_secret(provider_params, false), do: provider_params

  defp put_derived_slug(provider_params, true) do
    Map.put(provider_params, "slug", Provider.slugify(provider_params["name"] || ""))
  end

  defp put_derived_slug(provider_params, false), do: provider_params

  defp put_derived_redirect_uri(provider_params, true) do
    redirect_uri =
      if present?(provider_params["slug"]),
        do: UserOidcAuth.callback_url(provider_params["slug"]),
        else: ""

    Map.put(provider_params, "redirect_uri", redirect_uri)
  end

  defp put_derived_redirect_uri(provider_params, false), do: provider_params

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset)
    name = form[:name].value
    logo_url = form[:logo_url].value

    socket
    |> assign(:form, form)
    |> assign(:name_preview, if(present?(name), do: name, else: gettext("Provider")))
    |> assign(:logo_preview, if(present?(logo_url), do: logo_url, else: @default_logo))
  end

  defp present?(value), do: is_binary(value) and String.trim(value) != ""

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
