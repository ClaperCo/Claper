defmodule Claper.Admin do
  @moduledoc """
  The Admin context.
  Provides functions for admin dashboard statistics and paginated lists of resources.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Claper.Accounts.User
  alias Claper.Events.Event
  alias Claper.Accounts.Oidc.Provider

  @doc """
  Gets dashboard statistics.

  Returns a map with counts of users, events, and upcoming events.

  ## Examples

      iex> get_dashboard_stats()
      %{users_count: 10, events_count: 20, upcoming_events: 5}

  """
  def get_dashboard_stats do
    users_count =
      User
      |> where([u], is_nil(u.deleted_at))
      |> Repo.aggregate(:count, :id)

    events_count =
      Event
      |> Repo.aggregate(:count, :id)

    _now = NaiveDateTime.utc_now()

    upcoming_events =
      Event
      |> where([e], is_nil(e.expired_at))
      |> Repo.aggregate(:count, :id)

    %{
      users_count: users_count,
      events_count: events_count,
      upcoming_events: upcoming_events
    }
  end

  @doc """
  Gets users over time for analytics charts.

  Returns user registration data grouped by time period.

  ## Parameters
  - period: :day, :week, :month (default: :day)
  - days_back: number of days to look back (default: 30)

  ## Examples

      iex> get_users_over_time(:day, 7)
      %{
        labels: ["2025-01-10", "2025-01-11", ...],
        values: [2, 5, 1, 3, ...]
      }
  """
  def get_users_over_time(period \\ :day, days_back \\ 30) do
    end_date = NaiveDateTime.utc_now()
    start_date = NaiveDateTime.add(end_date, -(days_back * 24 * 60 * 60), :second)

    # Generate all dates in the range
    date_range = generate_date_range(start_date, end_date, period)

    # Get actual user counts per period using raw SQL to avoid parameter conflicts
    period_sql_value = period_sql(period)

    sql = """
    SELECT DATE_TRUNC($1, inserted_at) as period, COUNT(id) as count
    FROM users
    WHERE deleted_at IS NULL
    AND inserted_at >= $2
    AND inserted_at <= $3
    GROUP BY DATE_TRUNC($1, inserted_at)
    ORDER BY period
    """

    result = Repo.query!(sql, [period_sql_value, start_date, end_date])

    user_counts =
      result.rows
      |> Enum.map(fn [period, count] ->
        normalized_period = NaiveDateTime.truncate(period, :second)
        {normalized_period, count}
      end)
      |> Enum.into(%{})

    # Format data for charts
    labels = Enum.map(date_range, &format_date_label(&1, period))

    values =
      Enum.map(date_range, fn date ->
        Map.get(user_counts, truncate_date(date, period), 0)
      end)

    %{
      labels: labels,
      values: values
    }
  end

  @doc """
  Gets events over time for analytics charts.

  Returns event creation data grouped by time period.

  ## Parameters
  - period: :day, :week, :month (default: :day)
  - days_back: number of days to look back (default: 30)

  ## Examples

      iex> get_events_over_time(:day, 7)
      %{
        labels: ["2025-01-10", "2025-01-11", ...],
        values: [1, 3, 0, 2, ...]
      }
  """
  def get_events_over_time(period \\ :day, days_back \\ 30) do
    end_date = NaiveDateTime.utc_now()
    start_date = NaiveDateTime.add(end_date, -(days_back * 24 * 60 * 60), :second)

    # Generate all dates in the range
    date_range = generate_date_range(start_date, end_date, period)

    # Get actual event counts per period using raw SQL to avoid parameter conflicts
    period_sql_value = period_sql(period)

    sql = """
    SELECT DATE_TRUNC($1, inserted_at) as period, COUNT(id) as count
    FROM events
    WHERE inserted_at >= $2
    AND inserted_at <= $3
    GROUP BY DATE_TRUNC($1, inserted_at)
    ORDER BY period
    """

    result = Repo.query!(sql, [period_sql_value, start_date, end_date])

    event_counts =
      result.rows
      |> Enum.map(fn [period, count] ->
        # Normalize the timestamp by removing microseconds
        normalized_period = NaiveDateTime.truncate(period, :second)
        {normalized_period, count}
      end)
      |> Enum.into(%{})

    # Format data for charts
    labels = Enum.map(date_range, &format_date_label(&1, period))

    values =
      Enum.map(date_range, fn date ->
        Map.get(event_counts, truncate_date(date, period), 0)
      end)

    %{
      labels: labels,
      values: values
    }
  end

  @doc """
  Gets growth metrics for dashboard statistics.

  Returns percentage growth for users and events compared to previous period.
  """
  def get_growth_metrics do
    now = NaiveDateTime.utc_now()
    thirty_days_ago = NaiveDateTime.add(now, -(30 * 24 * 60 * 60), :second)
    sixty_days_ago = NaiveDateTime.add(now, -(60 * 24 * 60 * 60), :second)

    # Current period (last 30 days)
    current_users =
      User
      |> where([u], is_nil(u.deleted_at))
      |> where([u], u.inserted_at >= ^thirty_days_ago and u.inserted_at <= ^now)
      |> Repo.aggregate(:count, :id)

    current_events =
      Event
      |> where([e], e.inserted_at >= ^thirty_days_ago and e.inserted_at <= ^now)
      |> Repo.aggregate(:count, :id)

    # Previous period (30-60 days ago)
    previous_users =
      User
      |> where([u], is_nil(u.deleted_at))
      |> where([u], u.inserted_at >= ^sixty_days_ago and u.inserted_at < ^thirty_days_ago)
      |> Repo.aggregate(:count, :id)

    previous_events =
      Event
      |> where([e], e.inserted_at >= ^sixty_days_ago and e.inserted_at < ^thirty_days_ago)
      |> Repo.aggregate(:count, :id)

    %{
      users_growth: calculate_growth_percentage(current_users, previous_users),
      events_growth: calculate_growth_percentage(current_events, previous_events)
    }
  end

  @doc """
  Gets recent activity stats for dashboard.

  Returns counts of recent activities.
  """
  def get_activity_stats do
    now = NaiveDateTime.utc_now()
    twenty_four_hours_ago = NaiveDateTime.add(now, -(24 * 60 * 60), :second)
    seven_days_ago = NaiveDateTime.add(now, -(7 * 24 * 60 * 60), :second)

    %{
      users_today:
        User
        |> where([u], is_nil(u.deleted_at))
        |> where([u], u.inserted_at >= ^twenty_four_hours_ago)
        |> Repo.aggregate(:count, :id),
      events_today:
        Event
        |> where([e], e.inserted_at >= ^twenty_four_hours_ago)
        |> Repo.aggregate(:count, :id),
      users_this_week:
        User
        |> where([u], is_nil(u.deleted_at))
        |> where([u], u.inserted_at >= ^seven_days_ago)
        |> Repo.aggregate(:count, :id),
      events_this_week:
        Event
        |> where([e], e.inserted_at >= ^seven_days_ago)
        |> Repo.aggregate(:count, :id)
    }
  end

  # Private helper functions

  defp generate_date_range(start_date, end_date, period) do
    start_date
    |> NaiveDateTime.to_date()
    |> Date.range(NaiveDateTime.to_date(end_date))
    |> Enum.to_list()
    |> case do
      dates when period == :day ->
        dates

      dates when period == :week ->
        dates |> Enum.chunk_every(7) |> Enum.map(&List.first/1)

      dates when period == :month ->
        dates |> Enum.group_by(&Date.beginning_of_month/1) |> Map.keys()
    end
  end

  defp period_sql(period) do
    case period do
      :day -> "day"
      :week -> "week"
      :month -> "month"
    end
  end

  defp format_date_label(date, period) do
    case period do
      :day -> Date.to_string(date)
      :week -> "Week of #{Date.to_string(date)}"
      :month -> "#{Date.to_string(date) |> String.slice(0..6)}"
    end
  end

  defp truncate_date(date, period) do
    naive_date = NaiveDateTime.new!(date, ~T[00:00:00])

    case period do
      :day ->
        NaiveDateTime.truncate(naive_date, :second)

      :week ->
        days_to_subtract = Date.day_of_week(date) - 1

        date
        |> Date.add(-days_to_subtract)
        |> NaiveDateTime.new!(~T[00:00:00])
        |> NaiveDateTime.truncate(:second)

      :month ->
        date
        |> Date.beginning_of_month()
        |> NaiveDateTime.new!(~T[00:00:00])
        |> NaiveDateTime.truncate(:second)
    end
  end

  defp calculate_growth_percentage(current, previous) do
    cond do
      previous == 0 and current > 0 ->
        100.0

      previous == 0 and current == 0 ->
        0.0

      previous > 0 ->
        :erlang.float_to_binary(((current - previous) / previous * 100) |> Float.round(1),
          decimals: 1
        )

      true ->
        0.0
    end
  end

  @doc """
  Returns a paginated list of users.

  ## Options

  * `:page` - The page number (default: 1)
  * `:per_page` - The number of users per page (default: 20)
  * `:search` - Search term for filtering users by email
  * `:role` - Filter users by role name

  ## Examples

      iex> list_users_paginated(%{page: 1, per_page: 10})
      %{entries: [%User{}, ...], page_number: 1, page_size: 10, total_entries: 20, total_pages: 2}

  """
  def list_users_paginated(params \\ %{}) do
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)
    search = Map.get(params, "search", "")
    role = Map.get(params, "role", "")

    query =
      User
      |> where([u], is_nil(u.deleted_at))
      |> preload(:role)

    query =
      if search != "" do
        query |> where([u], ilike(u.email, ^"%#{search}%"))
      else
        query
      end

    query =
      if role != "" do
        query |> join(:inner, [u], r in assoc(u, :role), on: r.name == ^role)
      else
        query
      end

    query = query |> order_by([u], desc: u.inserted_at)

    Repo.paginate(query, page: page, page_size: per_page)
  end

  @doc """
  Returns a paginated list of events.

  ## Options

  * `:page` - The page number (default: 1)
  * `:per_page` - The number of events per page (default: 20)
  * `:search` - Search term for filtering events by name
  * `:status` - Filter events by status (upcoming, past)
  * `:start_date` - Filter events by start date
  * `:end_date` - Filter events by end date
  * `:creator_id` - Filter events by creator ID

  ## Examples

      iex> list_events_paginated(%{page: 1, per_page: 10})
      %{entries: [%Event{}, ...], page_number: 1, page_size: 10, total_entries: 20, total_pages: 2}

  """
  def list_events_paginated(params \\ %{}) do
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)
    search = Map.get(params, "search", "")
    status = Map.get(params, "status", "")
    start_date = Map.get(params, "start_date", nil)
    end_date = Map.get(params, "end_date", nil)
    creator_id = Map.get(params, "creator_id", nil)

    query =
      Event
      |> preload(:user)

    query =
      if search != "" do
        query |> where([e], ilike(e.name, ^"%#{search}%"))
      else
        query
      end

    query =
      case status do
        "upcoming" ->
          now = NaiveDateTime.utc_now()
          query |> where([e], e.started_at > ^now)

        "past" ->
          now = NaiveDateTime.utc_now()
          query |> where([e], e.started_at <= ^now)

        _ ->
          query
      end

    query =
      if start_date do
        query |> where([e], e.started_at >= ^start_date)
      else
        query
      end

    query =
      if end_date do
        query |> where([e], e.started_at <= ^end_date)
      else
        query
      end

    query =
      if creator_id do
        query |> where([e], e.user_id == ^creator_id)
      else
        query
      end

    query = query |> order_by([e], desc: e.started_at)

    Repo.paginate(query, page: page, page_size: per_page)
  end

  @doc """
  Returns a paginated list of OIDC providers.

  ## Options

  * `:page` - The page number (default: 1)
  * `:per_page` - The number of providers per page (default: 20)
  * `:search` - Search term for filtering providers by name

  ## Examples

      iex> list_oidc_providers_paginated(%{page: 1, per_page: 10})
      %{entries: [%Provider{}, ...], page_number: 1, page_size: 10, total_entries: 20, total_pages: 2}

  """
  def list_oidc_providers_paginated(params \\ %{}) do
    page = Map.get(params, "page", 1)
    per_page = Map.get(params, "per_page", 20)
    search = Map.get(params, "search", "")

    query = Provider

    query =
      if search != "" do
        query |> where([p], ilike(p.name, ^"%#{search}%"))
      else
        query
      end

    query = query |> order_by([p], p.name)

    Repo.paginate(query, page: page, page_size: per_page)
  end

  @doc """
  Returns a complete list of OIDC providers for export purposes.

  Unlike the paginated version, this returns all providers matching the search criteria.

  ## Options

  * `:search` - Search term for filtering providers by name

  ## Examples

      iex> list_all_oidc_providers(%{search: "Google"})
      [%Provider{}, ...]

  """
  def list_all_oidc_providers(params \\ %{}) do
    search = Map.get(params, "search", "")

    query = Provider

    query =
      if search != "" do
        query |> where([p], ilike(p.name, ^"%#{search}%"))
      else
        query
      end

    query = query |> order_by([p], p.name)

    Repo.all(query)
  end

  @doc """
  Returns a complete list of events for export purposes.

  Unlike the paginated version, this returns all events matching the search criteria.

  ## Options

  * `:search` - Search term for filtering events by name
  * `:status` - Filter events by status (upcoming, past)
  * `:start_date` - Filter events by start date
  * `:end_date` - Filter events by end date
  * `:creator_id` - Filter events by creator ID

  ## Examples

      iex> list_all_events(%{search: "Conference"})
      [%Event{}, ...]

  """
  def list_all_events(params \\ %{}) do
    Event
    |> join(:left, [e], u in assoc(e, :user))
    |> preload([e, u], user: u)
    |> apply_event_search_filter(Map.get(params, "search", ""))
    |> apply_event_status_filter(Map.get(params, "status", ""))
    |> apply_event_start_date_filter(Map.get(params, "start_date", nil))
    |> apply_event_end_date_filter(Map.get(params, "end_date", nil))
    |> apply_event_creator_filter(Map.get(params, "creator_id", nil))
    |> order_by([e], desc: e.started_at)
    |> Repo.all()
    |> Enum.map(fn event -> Map.put(event, :user_email, event.user.email) end)
  end

  defp apply_event_search_filter(query, ""), do: query

  defp apply_event_search_filter(query, search) do
    search_term = "%#{search}%"

    query
    |> where(
      [e, u],
      ilike(e.name, ^search_term) or ilike(e.code, ^search_term) or
        ilike(u.email, ^search_term)
    )
  end

  defp apply_event_status_filter(query, "upcoming") do
    now = NaiveDateTime.utc_now()
    query |> where([e], e.started_at > ^now)
  end

  defp apply_event_status_filter(query, "past") do
    now = NaiveDateTime.utc_now()
    query |> where([e], e.started_at <= ^now)
  end

  defp apply_event_status_filter(query, _), do: query

  defp apply_event_start_date_filter(query, nil), do: query

  defp apply_event_start_date_filter(query, start_date) do
    query |> where([e], e.started_at >= ^start_date)
  end

  defp apply_event_end_date_filter(query, nil), do: query

  defp apply_event_end_date_filter(query, end_date) do
    query |> where([e], e.started_at <= ^end_date)
  end

  defp apply_event_creator_filter(query, nil), do: query

  defp apply_event_creator_filter(query, creator_id) do
    query |> where([e], e.user_id == ^creator_id)
  end

  @doc """
  Returns a complete list of users for export purposes.

  Unlike the paginated version, this returns all users matching the search criteria.

  ## Options

  * `:search` - Search term for filtering users by email or name
  * `:role` - Filter users by role ID

  ## Examples

      iex> list_all_users(%{search: "admin"})
      [%User{}, ...]

  """
  def list_all_users(params \\ %{}) do
    search = Map.get(params, "search", "")
    role = Map.get(params, "role", "")

    query =
      User
      |> where([u], is_nil(u.deleted_at))
      |> preload(:role)

    query =
      if search != "" do
        query |> where([u], ilike(u.email, ^"%#{search}%") or ilike(u.name, ^"%#{search}%"))
      else
        query
      end

    query =
      if role != "" do
        query |> where([u], u.role_id == ^role)
      else
        query
      end

    query = query |> order_by([u], u.email)

    # Add a virtual field for role_name to make it accessible in CSV export
    Repo.all(query)
    |> Enum.map(fn user ->
      role_name = if user.role, do: user.role.name, else: "none"

      user
      |> Map.put(:role_name, role_name)
    end)
  end
end
