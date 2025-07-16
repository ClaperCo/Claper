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

    now = NaiveDateTime.utc_now()
    upcoming_events =
      Event
      |> where([e], e.started_at > ^now)
      |> Repo.aggregate(:count, :id)

    %{
      users_count: users_count,
      events_count: events_count,
      upcoming_events: upcoming_events
    }
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

    # Add a virtual field for user_email to make it accessible in CSV export
    Repo.all(query)
    |> Enum.map(fn event ->
      Map.put(event, :user_email, event.user.email)
    end)
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
