defmodule ClaperWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use ClaperWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ClaperWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import ClaperWeb.ConnCase
      import Ecto.Query

      alias ClaperWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint ClaperWeb.Endpoint
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Claper.Repo, shared: not tags[:async])

    on_exit(fn ->
      drain_task_supervisor(Claper.TaskSupervisor)
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn() |> Map.put(:remote_ip, unique_remote_ip())}
  end

  defp unique_remote_ip do
    suffix = System.unique_integer([:positive])

    {
      127,
      rem(div(suffix, 65_536), 256),
      rem(div(suffix, 256), 256),
      rem(suffix, 256)
    }
  end

  defp drain_task_supervisor(supervisor) do
    supervisor
    |> Task.Supervisor.children()
    |> Enum.each(fn pid ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        1_000 -> Process.demonitor(ref, [:flush])
      end
    end)
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Claper.AccountsFixtures.confirmed_user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Setup helper that registers and logs in an administrator.

      setup :register_and_log_in_admin

  It stores an updated connection and the administrator in the test context.
  """
  def register_and_log_in_admin(%{conn: conn}) do
    ensure_role("user")
    ensure_role("admin")

    {:ok, admin} =
      Claper.AccountsFixtures.confirmed_user_fixture()
      |> Claper.Accounts.assign_role("admin")

    %{conn: log_in_user(conn, admin), admin: admin}
  end

  defp ensure_role(name) do
    Claper.Accounts.get_role_by_name(name) ||
      case Claper.Accounts.create_role(%{name: name}) do
        {:ok, role} -> role
        {:error, _changeset} -> Claper.Accounts.get_role_by_name(name)
      end
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Claper.Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:current_user, user)
    |> Plug.Conn.put_session(:user_token, token)
  end
end
