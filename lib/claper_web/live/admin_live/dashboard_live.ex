defmodule ClaperWeb.AdminLive.DashboardLive do
  use ClaperWeb, :live_view

  import Ecto.Query, warn: false
  alias Claper.Admin
  alias Claper.Events.Event
  alias Claper.Repo

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      # Set up periodic updates every 30 seconds
      :timer.send_interval(30_000, self(), :update_charts)
    end

    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    socket =
      socket
      |> assign(:page_title, gettext("Dashboard"))
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

    days_back =
      case period_atom do
        :day -> 30
        # 12 weeks
        :week -> 84
        # 12 months
        :month -> 365
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

    # Get recent events for the dashboard
    recent_events =
      Event
      |> order_by([e], desc: e.started_at)
      |> limit(5)
      |> preload(:user)
      |> Repo.all()

    # Transform stats to match template expectations
    transformed_stats = %{
      total_users: stats.users_count,
      total_events: stats.events_count,
      active_events: stats.upcoming_events
    }

    socket
    |> assign(:stats, transformed_stats)
    |> assign(:growth_metrics, growth_metrics)
    |> assign(:activity_stats, activity_stats)
    |> assign(:recent_events, recent_events)
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
end
