defmodule Claper.Audit do
  @moduledoc """
  The Audit context for tracking actions in the system.
  """

  import Ecto.Query, only: [from: 2]

  alias Claper.{Accounts, Repo}
  alias Claper.Audit.Log

  @doc """
  Logs an action.

  ## Examples

      iex> log_action(user, "user.login", %{ip_address: "127.0.0.1"})
      {:ok, %Log{}}

      iex> log_action(nil, "system.startup", %{})
      {:ok, %Log{}}

  """
  def log_action(user, action, metadata \\ %{})

  def log_action(%Accounts.User{} = user, action, metadata) do
    create_log(%{
      user_id: user.id,
      action: action,
      metadata: metadata
    })
  end

  def log_action(nil, action, metadata) do
    create_log(%{
      action: action,
      metadata: metadata
    })
  end

  @doc """
  Logs an action related to a specific resource.

  ## Examples

      iex> log_resource_action(user, "event.create", "event", 123, %{})
      {:ok, %Log{}}

  """
  def log_resource_action(
        %Accounts.User{} = user,
        action,
        resource_type,
        resource_id,
        metadata \\ %{}
      ) do
    create_log(%{
      user_id: user.id,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      metadata: metadata
    })
  end

  @doc """
  Returns a paginated, optionally filtered and sorted, list of audit logs.
  """
  def list_logs(params \\ %{}) do
    query = from l in Log, left_join: u in assoc(l, :user), as: :user, preload: [user: u]
    Flop.validate_and_run!(query, params, for: Log, replace_invalid_params: true)
  end

  @doc """
  Returns a list of distinct action types for filtering.
  """
  def list_action_types do
    from(l in Log,
      distinct: true,
      select: l.action,
      order_by: l.action
    )
    |> Repo.all()
  end

  @doc """
  Gets a single log.

  Raises `Ecto.NoResultsError` if the Log does not exist.

  ## Examples

      iex> get_log!(123)
      %Log{}

      iex> get_log!(456)
      ** (Ecto.NoResultsError)

  """
  def get_log!(id) do
    Repo.one!(
      from l in Log, left_join: u in assoc(l, :user), where: l.id == ^id, preload: [user: u]
    )
  end

  @doc """
  Creates a log entry.

  This is a simple wrapper over a low-level insert. You likely want to use
  `log_action/3` and `log_resource_action/5` instead.

  ## Examples

      iex> create_log(%{action: "user.login"})
      {:ok, %Log{}}

      iex> create_log(%{action: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_log(attrs \\ %{}) do
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end
end
