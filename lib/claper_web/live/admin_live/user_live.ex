defmodule ClaperWeb.AdminLive.UserLive do
  use ClaperWeb, :live_view

  alias Claper.Admin
  alias Claper.Accounts
  alias Claper.Accounts.User
  alias ClaperWeb.Helpers.CSVExporter

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    {:ok,
     socket
     |> assign(:page_title, gettext("Users"))
     |> assign(:users, list_users())
     |> assign(:search, "")
     |> assign(:current_sort, %{field: :na, order: :asc})}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New user"))
    |> assign(:user, %User{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit user"))
    |> assign(:user, Accounts.get_user!(id) |> Claper.Repo.preload(:role))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("User details"))
    |> assign(:user, Accounts.get_user!(id) |> Claper.Repo.preload(:role))
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)

    {:noreply,
     socket
     |> put_flash(:info, gettext("User deleted successfully"))
     |> assign(:users, list_users())}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field_atom = String.to_existing_atom(field)
    current_sort = socket.assigns.current_sort

    new_direction =
      if current_sort.field == field_atom do
        if current_sort.order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    users = sort_users(socket.assigns.users, field_atom, new_direction)
    current_sort = %{field: field_atom, order: new_direction}

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:current_sort, current_sort)}
  end

  @impl true
  def handle_info({:search_filter_changed, %{search: search, filters: _filters}}, socket) do
    users = search_users(search)
    {:noreply, socket |> assign(:search, search) |> assign(:users, users)}
  end

  @impl true
  def handle_info({:export_csv_requested, _params}, socket) do
    filename = CSVExporter.generate_filename("users")
    csv_content = CSVExporter.export_users_to_csv(socket.assigns.users)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Users exported successfully"))
     |> push_event("download_csv", %{filename: filename, content: csv_content})}
  end

  @impl true
  def handle_info({:table_sort_changed, sort_config}, socket) do
    %{field: field, direction: direction} = sort_config
    users = sort_users(socket.assigns.users, field, direction)
    current_sort = %{field: field, order: direction}

    {:noreply,
     socket
     |> assign(:users, users)
     |> assign(:current_sort, current_sort)}
  end

  @impl true
  def handle_info({:table_action, action, user, _user_id}, socket) do
    case action do
      :view ->
        {:noreply, push_navigate(socket, to: ~p"/admin/users/#{user}")}

      :edit ->
        {:noreply, push_navigate(socket, to: ~p"/admin/users/#{user}/edit")}

      :delete ->
        {:ok, _} = Accounts.delete_user(user)

        {:noreply,
         socket
         |> put_flash(:info, gettext("User deleted successfully"))
         |> assign(:users, list_users())}
    end
  end

  def list_users do
    Admin.list_all_users()
  end

  defp search_users(search) when search == "", do: list_users()

  defp search_users(search) do
    Admin.list_all_users(%{"search" => search})
  end

  defp sort_users(users, field, order) do
    Enum.sort_by(users, &Map.get(&1, field), order)
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
