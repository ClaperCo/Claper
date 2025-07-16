defmodule ClaperWeb.AdminLive.DashboardLive do
  use ClaperWeb, :live_view

  import Ecto.Query, warn: false
  alias Claper.Admin
  alias Claper.Events.Event
  alias Claper.Repo

  @impl true
  def mount(_params, _session, socket) do
    stats = Admin.get_dashboard_stats()

    # Get upcoming events for the dashboard
    upcoming_events =
      Event
      |> where([e], e.started_at > ^NaiveDateTime.utc_now())
      |> order_by([e], asc: e.started_at)
      |> limit(10)
      |> preload(:user)
      |> Repo.all()

    socket =
      socket
      |> assign(:stats, stats)
      |> assign(:upcoming_events, upcoming_events)
      |> assign(:page_title, "Admin Dashboard")

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-6">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <h1 class="text-2xl font-semibold text-gray-900">Dashboard</h1>
      </div>
      <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
        <div class="py-4">
          <!-- Stats Section -->
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3 mb-8">
            <!-- Total Users -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Total Users
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        <%= @stats.users_count %>
                      </div>
                    </dd>
                  </div>
                </div>
              </div>
            </div>

            <!-- Total Events -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Total Events
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        <%= @stats.events_count %>
                      </div>
                    </dd>
                  </div>
                </div>
              </div>
            </div>

            <!-- Active Events -->
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center">
                  <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
                    <svg class="h-6 w-6 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Active Events
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        <%= @stats.upcoming_events %>
                      </div>
                    </dd>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Upcoming Events Section -->
          <div class="bg-white shadow overflow-hidden sm:rounded-lg mb-8">
            <div class="px-4 py-5 sm:px-6">
              <h2 class="text-lg leading-6 font-medium text-gray-900">Upcoming Events</h2>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">Next 10 scheduled events</p>
            </div>
            <div class="border-t border-gray-200">
              <div class="bg-white overflow-hidden shadow-md sm:rounded-lg">
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                        <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Code</th>
                        <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Owner</th>
                        <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Start Date</th>
                        <th scope="col" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= if Enum.empty?(@upcoming_events) do %>
                        <tr>
                          <td colspan="5" class="px-6 py-4 text-center text-sm text-gray-500">No upcoming events</td>
                        </tr>
                      <% else %>
                        <%= for event <- @upcoming_events do %>
                          <tr>
                            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= event.name %></td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= event.code %></td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= event.user.email %></td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                              <%= Calendar.strftime(event.started_at, "%Y-%m-%d %H:%M") %>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                              <.link navigate={~p"/admin/events/#{event.id}"} class="text-indigo-600 hover:text-indigo-900">
                                View
                              </.link>
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

          <!-- Quick Links Section -->
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900">User Management</h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>Manage users, roles, and permissions</p>
                </div>
                <div class="mt-5">
                  <.link navigate={~p"/admin/users"} class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                    Go to Users
                  </.link>
                </div>
              </div>
            </div>

            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Event Management</h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>Manage events, polls, and interactions</p>
                </div>
                <div class="mt-5">
                  <.link navigate={~p"/admin/events"} class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                    Go to Events
                  </.link>
                </div>
              </div>
            </div>

            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg leading-6 font-medium text-gray-900">OIDC Provider Management</h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>Manage OIDC authentication providers</p>
                </div>
                <div class="mt-5">
                  <.link navigate={~p"/admin/oidc_providers"} class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
                    Go to OIDC Providers
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
