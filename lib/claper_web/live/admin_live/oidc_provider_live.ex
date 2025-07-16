defmodule ClaperWeb.AdminLive.OidcProviderLive do
  use ClaperWeb, :live_view

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider
  alias ClaperWeb.AdminLive.OidcProviderLive.FormComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, 
      socket
      |> assign(:page_title, "Admin - OIDC Providers")
      |> assign(:providers, list_providers())
      |> assign(:search, "")
      |> assign(:current_sort, %{field: :name, order: :asc})
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "OIDC Providers")
    |> assign(:provider, nil)
  end
  
  defp apply_action(socket, :show, %{"id" => id}) do
    provider = Oidc.get_provider!(id)
    
    socket
    |> assign(:page_title, "OIDC Provider Details")
    |> assign(:provider, provider)
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New OIDC Provider")
    |> assign(:provider, %Provider{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit OIDC Provider")
    |> assign(:provider, Oidc.get_provider!(id))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, "OIDC Provider Details")
    |> assign(:provider, Oidc.get_provider!(id))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Oidc.get_provider!(id)
    {:ok, _} = Oidc.delete_provider(provider)

    {:noreply,
     socket
     |> put_flash(:info, "OIDC provider deleted successfully")
     |> assign(:providers, list_providers())}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    providers = search_providers(search)
    {:noreply, socket |> assign(:search, search) |> assign(:providers, providers)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    %{current_sort: %{field: current_field, order: current_order}} = socket.assigns
    
    {field, order} = 
      if current_field == String.to_existing_atom(field) do
        {current_field, if(current_order == :asc, do: :desc, else: :asc)}
      else
        {String.to_existing_atom(field), :asc}
      end
    
    providers = sort_providers(socket.assigns.providers, field, order)
    
    {:noreply, 
      socket
      |> assign(:providers, providers)
      |> assign(:current_sort, %{field: field, order: order})
    }
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    provider = Oidc.get_provider!(id)
    {:ok, updated_provider} = Oidc.update_provider(provider, %{active: !provider.active})

    {:noreply,
     socket
     |> put_flash(:info, "Provider #{if updated_provider.active, do: "activated", else: "deactivated"} successfully")
     |> assign(:providers, list_providers())}
  end

  defp list_providers do
    Oidc.list_providers()
  end

  defp search_providers(search) when search == "", do: list_providers()
  defp search_providers(search) do
    search_term = "%#{search}%"
    Oidc.search_providers(search_term)
  end

  defp sort_providers(providers, field, order) do
    Enum.sort_by(providers, &Map.get(&1, field), order)
  end

  @impl true
  def render(assigns) do
    case assigns.live_action do
      :index -> render_index(assigns)
      :show -> render_show(assigns)
      :new -> render_new(assigns)
      :edit -> render_edit(assigns)
    end
  end
  
  defp render_index(assigns) do
    ~H"""
    <div class="py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-semibold text-gray-900">OIDC Providers</h1>
          <div class="flex space-x-3">
            <.link navigate={~p"/admin/oidc_providers/new"} class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              New Provider
            </.link>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mt-4">
        <div class="py-4">
          <!-- Search Bar -->
          <div class="mb-4">
            <form phx-change="search" class="flex w-full md:w-1/2">
              <div class="relative flex-grow">
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" />
                  </svg>
                </div>
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Search providers..."
                  class="focus:ring-indigo-500 focus:border-indigo-500 block w-full pl-10 sm:text-sm border-gray-300 rounded-md"
                />
              </div>
            </form>
          </div>

          <!-- Providers Table -->
          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                  <tr>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <button phx-click="sort" phx-value-field="name" class="group inline-flex">
                        Name
                        <%= sort_indicator(@current_sort, :name) %>
                      </button>
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <button phx-click="sort" phx-value-field="issuer" class="group inline-flex">
                        Issuer
                        <%= sort_indicator(@current_sort, :issuer) %>
                      </button>
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <button phx-click="sort" phx-value-field="active" class="group inline-flex">
                        Status
                        <%= sort_indicator(@current_sort, :active) %>
                      </button>
                    </th>
                    <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      <button phx-click="sort" phx-value-field="inserted_at" class="group inline-flex">
                        Created
                        <%= sort_indicator(@current_sort, :inserted_at) %>
                      </button>
                    </th>
                    <th scope="col" class="relative px-6 py-3">
                      <span class="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                  <%= if Enum.empty?(@providers) do %>
                    <tr>
                      <td colspan="5" class="px-6 py-4 text-center text-sm text-gray-500">No OIDC providers found</td>
                    </tr>
                  <% else %>
                    <%= for provider <- @providers do %>
                      <tr id={"provider-#{provider.id}"}>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                          <%= provider.name %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          <%= provider.issuer %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                          <button phx-click="toggle_active" phx-value-id={provider.id} class="focus:outline-none">
                            <%= if provider.active do %>
                              <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                                Active
                              </span>
                            <% else %>
                              <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                                Inactive
                              </span>
                            <% end %>
                          </button>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                          <%= Calendar.strftime(provider.inserted_at, "%Y-%m-%d %H:%M") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                          <div class="flex justify-end space-x-3">
                            <.link navigate={~p"/admin/oidc_providers/#{provider}"} class="text-indigo-600 hover:text-indigo-900">
                              View
                            </.link>
                            <.link navigate={~p"/admin/oidc_providers/#{provider}/edit"} class="text-indigo-600 hover:text-indigo-900">
                              Edit
                            </.link>
                            <a href="#" phx-click="delete" phx-value-id={provider.id} data-confirm="Are you sure you want to delete this provider?" class="text-red-600 hover:text-red-900">
                              Delete
                            </a>
                          </div>
                        </td>
                      </tr>
                    <% end %>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp render_show(assigns) do
    ~H"""
    <div class="py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-semibold text-gray-900">OIDC Provider Details</h1>
          <div class="flex space-x-3">
            <.link navigate={~p"/admin/oidc_providers"} class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Back to Providers
            </.link>
            <.link navigate={~p"/admin/oidc_providers/#{@provider}/edit"} class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Edit
            </.link>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mt-4">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6">
            <h3 class="text-lg leading-6 font-medium text-gray-900"><%= @provider.name %></h3>
            <p class="mt-1 max-w-2xl text-sm text-gray-500">OIDC Provider</p>
          </div>
          <div class="border-t border-gray-200 px-4 py-5 sm:p-0">
            <dl class="sm:divide-y sm:divide-gray-200">
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Name</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @provider.name %></dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Issuer</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @provider.issuer %></dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Client ID</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @provider.client_id %></dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Response Type</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @provider.response_type %></dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Scope</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @provider.scope %></dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Status</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                  <%= if @provider.active do %>
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                      Active
                    </span>
                  <% else %>
                    <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800">
                      Inactive
                    </span>
                  <% end %>
                </dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Created At</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                  <%= Calendar.strftime(@provider.inserted_at, "%Y-%m-%d %H:%M") %>
                </dd>
              </div>
              <div class="py-4 sm:py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
                <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
                <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                  <%= Calendar.strftime(@provider.updated_at, "%Y-%m-%d %H:%M") %>
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  defp render_new(assigns) do
    ~H"""
    <div class="py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-semibold text-gray-900">New OIDC Provider</h1>
          <div class="flex space-x-3">
            <.link navigate={~p"/admin/oidc_providers"} class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Back to Providers
            </.link>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mt-4">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg p-6">
          <.live_component
            module={FormComponent}
            id="provider-form"
            title="New OIDC Provider"
            action={:new}
            provider={@provider}
            navigate={~p"/admin/oidc_providers"}
          />
        </div>
      </div>
    </div>
    """
  end
  
  defp render_edit(assigns) do
    ~H"""
    <div class="py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <div class="flex justify-between items-center">
          <h1 class="text-2xl font-semibold text-gray-900">Edit OIDC Provider</h1>
          <div class="flex space-x-3">
            <.link navigate={~p"/admin/oidc_providers"} class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
              Back to Providers
            </.link>
          </div>
        </div>
      </div>

      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mt-4">
        <div class="bg-white shadow overflow-hidden sm:rounded-lg p-6">
          <.live_component
            module={FormComponent}
            id={"provider-form-#{@provider.id}"}
            title="Edit OIDC Provider"
            action={:edit}
            provider={@provider}
            navigate={~p"/admin/oidc_providers"}
          />
        </div>
      </div>
    </div>
    """
  end

  defp sort_indicator(current_sort, field) do
    assigns = %{current_sort: current_sort, field: field}
    
    ~H"""
    <%= if @current_sort.field == @field do %>
      <%= if @current_sort.order == :asc do %>
        <svg class="ml-2 h-5 w-5 text-gray-500 group-hover:text-gray-700" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M5.293 7.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L6.707 7.707a1 1 0 01-1.414 0z" clip-rule="evenodd" />
        </svg>
      <% else %>
        <svg class="ml-2 h-5 w-5 text-gray-500 group-hover:text-gray-700" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
          <path fill-rule="evenodd" d="M14.707 12.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd" />
        </svg>
      <% end %>
    <% else %>
      <svg class="ml-2 h-5 w-5 text-gray-400 opacity-0 group-hover:opacity-100" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
        <path fill-rule="evenodd" d="M10 3a1 1 0 01.707.293l3 3a1 1 0 01-1.414 1.414L10 5.414 7.707 7.707a1 1 0 01-1.414-1.414l3-3A1 1 0 0110 3zm-3.707 9.293a1 1 0 011.414 0L10 14.586l2.293-2.293a1 1 0 011.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clip-rule="evenodd" />
      </svg>
    <% end %>
    """
  end
end
