defmodule ClaperWeb.AdminLive.OidcProviderLive do
  use ClaperWeb, :live_view

  alias Claper.Accounts.Oidc
  alias Claper.Accounts.Oidc.Provider

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    {:ok,
     socket
     |> assign(:page_title, gettext("OIDC Providers"))
     |> assign(:providers, list_providers())
     |> assign(:search, "")
     |> assign(:current_sort, %{field: :na, order: :asc})}
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
    socket
    |> assign(:page_title, gettext("Provider details"))
    |> assign(:provider, Oidc.get_provider!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New provider"))
    |> assign(:provider, %Provider{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit provider"))
    |> assign(:provider, Oidc.get_provider!(id))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    provider = Oidc.get_provider!(id)
    {:ok, _} = Oidc.delete_provider(provider)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Provider deleted successfully"))
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
     |> assign(:current_sort, %{field: field, order: order})}
  end

  @impl true
  def handle_info(
        {ClaperWeb.AdminLive.OidcProviderLive.FormComponent, {:saved, _provider}},
        socket
      ) do
    {:noreply, assign(socket, :providers, list_providers())}
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

  def sort_indicator(assigns) do
    ~H"""
    <%= if @current_sort.field == @field do %>
      <%= if @current_sort.order == :asc do %>
        <svg
          class="ml-2 h-5 w-5 text-gray-500 group-hover:text-gray-700"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M5.293 7.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L6.707 7.707a1 1 0 01-1.414 0z"
            clip-rule="evenodd"
          />
        </svg>
      <% else %>
        <svg
          class="ml-2 h-5 w-5 text-gray-500 group-hover:text-gray-700"
          xmlns="http://www.w3.org/2000/svg"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path
            fill-rule="evenodd"
            d="M14.707 12.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l2.293-2.293a1 1 0 011.414 0z"
            clip-rule="evenodd"
          />
        </svg>
      <% end %>
    <% else %>
      <svg
        class="ml-2 h-5 w-5 text-gray-400 opacity-0 group-hover:opacity-100"
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 20 20"
        fill="currentColor"
      >
        <path
          fill-rule="evenodd"
          d="M10 3a1 1 0 01.707.293l3 3a1 1 0 01-1.414 1.414L10 5.414 7.707 7.707a1 1 0 01-1.414-1.414l3-3A1 1 0 0110 3zm-3.707 9.293a1 1 0 011.414 0L10 14.586l2.293-2.293a1 1 0 011.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z"
          clip-rule="evenodd"
        />
      </svg>
    <% end %>
    """
  end
end
