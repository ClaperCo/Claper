defmodule ClaperWeb.AdminLive.DashboardLive do
  use ClaperWeb, :live_view

  import Ecto.Query, warn: false
  alias Claper.Admin
  alias Claper.Events.Event
  alias Claper.Repo

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Set up periodic updates every 30 seconds
      :timer.send_interval(30_000, self(), :update_charts)
    end

    socket = 
      socket
      |> assign(:page_title, "Admin Dashboard")
      |> assign(:selected_period, :day)
      |> assign(:days_back, 30)
      |> load_dashboard_data()

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("change_period", %{"period" => period}, socket) do
    period_atom = String.to_atom(period)
    
    days_back = case period_atom do
      :day -> 30
      :week -> 84  # 12 weeks
      :month -> 365 # 12 months
      _ -> 30
    end

    socket =
      socket
      |> assign(:selected_period, period_atom)
      |> assign(:days_back, days_back)
      |> load_chart_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_data", _params, socket) do
    socket = load_dashboard_data(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:update_charts, socket) do
    socket = load_chart_data(socket)
    {:noreply, socket}
  end

  defp load_dashboard_data(socket) do
    stats = Admin.get_dashboard_stats()
    growth_metrics = Admin.get_growth_metrics()
    activity_stats = Admin.get_activity_stats()

    # Get upcoming events for the dashboard
    upcoming_events =
      Event
      |> where([e], e.started_at > ^NaiveDateTime.utc_now())
      |> order_by([e], asc: e.started_at)
      |> limit(10)
      |> preload(:user)
      |> Repo.all()

    socket
    |> assign(:stats, stats)
    |> assign(:growth_metrics, growth_metrics)
    |> assign(:activity_stats, activity_stats)
    |> assign(:upcoming_events, upcoming_events)
    |> load_chart_data()
  end

  defp load_chart_data(socket) do
    period = socket.assigns.selected_period
    days_back = socket.assigns.days_back

    users_chart_data = Admin.get_users_over_time(period, days_back)
    events_chart_data = Admin.get_events_over_time(period, days_back)

    socket
    |> assign(:users_chart_data, users_chart_data)
    |> assign(:events_chart_data, events_chart_data)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen admin-background">
      <div class="relative z-10 py-8">
        <!-- Header Section -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mb-8">
          <div class="flex justify-between items-center">
            <div>
              <h1 class="text-4xl font-bold glass-text-primary mb-2">Admin Dashboard</h1>
              <p class="glass-text-secondary">Welcome to your analytics command center</p>
            </div>
            <div class="flex items-center space-x-4">
              <button phx-click="refresh_data" class="glass-button px-4 py-2">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                </svg>
                Refresh
              </button>
              <form phx-change="change_period" class="flex items-center">
                <label class="glass-text-primary mr-2 text-sm">Time Period:</label>
                <select name="period" class="glass-select px-3 py-2 text-sm">
                  <option value="day" selected={@selected_period == :day}>Daily</option>
                  <option value="week" selected={@selected_period == :week}>Weekly</option>
                  <option value="month" selected={@selected_period == :month}>Monthly</option>
                </select>
              </form>
            </div>
          </div>
        </div>

        <!-- Stats Grid -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mb-8">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <!-- Total Users -->
            <div class="glass-stat-card p-6">
              <div class="flex items-center">
                <div class="glass-icon mr-4">
                  <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="glass-text-secondary text-sm font-medium">Total Users</h3>
                  <p class="glass-text-primary text-3xl font-bold"><%= @stats.users_count %></p>
                  <div class="flex items-center mt-2">
                    <%= if @growth_metrics.users_growth >= 0 do %>
                      <svg class="w-4 h-4 text-gray-600 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                      </svg>
                      <span class="text-gray-600 text-sm">+<%= @growth_metrics.users_growth %>%</span>
                    <% else %>
                      <svg class="w-4 h-4 text-gray-600 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/>
                      </svg>
                      <span class="text-gray-600 text-sm"><%= @growth_metrics.users_growth %>%</span>
                    <% end %>
                    <span class="glass-text-muted text-sm ml-2">vs last month</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Total Events -->
            <div class="glass-stat-card p-6">
              <div class="flex items-center">
                <div class="glass-icon mr-4">
                  <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="glass-text-secondary text-sm font-medium">Total Events</h3>
                  <p class="glass-text-primary text-3xl font-bold"><%= @stats.events_count %></p>
                  <div class="flex items-center mt-2">
                    <%= if @growth_metrics.events_growth >= 0 do %>
                      <svg class="w-4 h-4 text-gray-600 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                      </svg>
                      <span class="text-gray-600 text-sm">+<%= @growth_metrics.events_growth %>%</span>
                    <% else %>
                      <svg class="w-4 h-4 text-gray-600 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/>
                      </svg>
                      <span class="text-gray-600 text-sm"><%= @growth_metrics.events_growth %>%</span>
                    <% end %>
                    <span class="glass-text-muted text-sm ml-2">vs last month</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Active Events -->
            <div class="glass-stat-card p-6">
              <div class="flex items-center">
                <div class="glass-icon mr-4">
                  <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="glass-text-secondary text-sm font-medium">Active Events</h3>
                  <p class="glass-text-primary text-3xl font-bold"><%= @stats.upcoming_events %></p>
                  <div class="flex items-center mt-2">
                    <span class="glass-text-muted text-sm">Currently running</span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Today's Activity -->
            <div class="glass-stat-card p-6">
              <div class="flex items-center">
                <div class="glass-icon mr-4">
                  <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="glass-text-secondary text-sm font-medium">Today's Activity</h3>
                  <p class="glass-text-primary text-3xl font-bold"><%= @activity_stats.users_today + @activity_stats.events_today %></p>
                  <div class="flex items-center mt-2">
                    <span class="glass-text-muted text-sm"><%= @activity_stats.users_today %> users, <%= @activity_stats.events_today %> events</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Charts Section -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mb-8">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <!-- Users Chart -->
            <div id="users-chart-container" class="glass-chart-container" phx-hook="AdminChart" data-chart-type="users" data-chart-data={Jason.encode!(@users_chart_data)}>
              <div class="flex justify-between items-center mb-6">
                <h3 class="glass-text-primary text-xl font-semibold">User Growth</h3>
                <div class="glass-text-secondary text-sm">
                  <%= String.capitalize(to_string(@selected_period)) %>ly view
                </div>
              </div>
              <div class="h-80">
                <canvas id="users-chart"></canvas>
              </div>
            </div>

            <!-- Events Chart -->
            <div id="events-chart-container" class="glass-chart-container" phx-hook="AdminChart" data-chart-type="events" data-chart-data={Jason.encode!(@events_chart_data)}>
              <div class="flex justify-between items-center mb-6">
                <h3 class="glass-text-primary text-xl font-semibold">Event Creation</h3>
                <div class="glass-text-secondary text-sm">
                  <%= String.capitalize(to_string(@selected_period)) %>ly view
                </div>
              </div>
              <div class="h-80">
                <canvas id="events-chart"></canvas>
              </div>
            </div>
          </div>
        </div>

        <!-- Upcoming Events Section -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8 mb-8">
          <div class="glass-table">
            <div class="glass-table-header px-6 py-4">
              <h3 class="glass-text-primary text-lg font-semibold">Upcoming Events</h3>
              <p class="glass-text-secondary text-sm mt-1">Next 10 scheduled events</p>
            </div>
            <div class="overflow-x-auto">
              <table class="min-w-full">
                <thead>
                  <tr class="glass-table-header">
                    <th class="px-6 py-3 text-left text-xs font-medium glass-text-primary uppercase tracking-wider">Name</th>
                    <th class="px-6 py-3 text-left text-xs font-medium glass-text-primary uppercase tracking-wider">Code</th>
                    <th class="px-6 py-3 text-left text-xs font-medium glass-text-primary uppercase tracking-wider">Owner</th>
                    <th class="px-6 py-3 text-left text-xs font-medium glass-text-primary uppercase tracking-wider">Start Date</th>
                    <th class="px-6 py-3 text-left text-xs font-medium glass-text-primary uppercase tracking-wider">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= if Enum.empty?(@upcoming_events) do %>
                    <tr class="glass-table-row">
                      <td colspan="5" class="px-6 py-8 text-center glass-text-secondary">
                        <div class="flex flex-col items-center">
                          <svg class="w-12 h-12 glass-text-muted mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          <p class="text-lg">No upcoming events</p>
                          <p class="text-sm glass-text-muted">Create your first event to get started</p>
                        </div>
                      </td>
                    </tr>
                  <% else %>
                    <%= for event <- @upcoming_events do %>
                      <tr class="glass-table-row">
                        <td class="px-6 py-4 whitespace-nowrap">
                          <div class="text-sm font-medium glass-text-primary"><%= event.name %></div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap">
                          <div class="glass-button-primary px-3 py-1 rounded-full text-xs font-medium">
                            <%= event.code %>
                          </div>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm glass-text-secondary">
                          <%= event.user.email %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-sm glass-text-secondary">
                          <%= Calendar.strftime(event.started_at, "%Y-%m-%d %H:%M") %>
                        </td>
                        <td class="px-6 py-4 whitespace-nowrap text-right text-sm">
                          <.link navigate={~p"/admin/events/#{event.id}"} class="glass-button-primary px-3 py-1 rounded-md text-xs">
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

        <!-- Quick Actions Section -->
        <div class="max-w-7xl mx-auto px-4 sm:px-6 md:px-8">
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div class="glass-card p-6">
              <div class="flex items-center mb-4">
                <div class="glass-icon mr-4">
                  <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <h3 class="glass-text-primary text-lg font-semibold">User Management</h3>
              </div>
              <p class="glass-text-secondary text-sm mb-4">Manage users, roles, and permissions</p>
              <.link navigate={~p"/admin/users"} class="glass-button-primary px-4 py-2 rounded-md text-sm font-medium">
                Go to Users
              </.link>
            </div>

            <div class="glass-card p-6">
              <div class="flex items-center mb-4">
                <div class="glass-icon mr-4">
                  <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
                <h3 class="glass-text-primary text-lg font-semibold">Event Management</h3>
              </div>
              <p class="glass-text-secondary text-sm mb-4">Manage events, polls, and interactions</p>
              <.link navigate={~p"/admin/events"} class="glass-button-primary px-4 py-2 rounded-md text-sm font-medium">
                Go to Events
              </.link>
            </div>

            <div class="glass-card p-6">
              <div class="flex items-center mb-4">
                <div class="glass-icon mr-4">
                  <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                  </svg>
                </div>
                <h3 class="glass-text-primary text-lg font-semibold">OIDC Providers</h3>
              </div>
              <p class="glass-text-secondary text-sm mb-4">Manage authentication providers</p>
              <.link navigate={~p"/admin/oidc_providers"} class="glass-button-primary px-4 py-2 rounded-md text-sm font-medium">
                Go to OIDC
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
