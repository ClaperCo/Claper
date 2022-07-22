defmodule ClaperWeb.LayoutView do
  use ClaperWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def active_class(conn, path) do
    current_path = Path.join(["/" | conn.path_info])
    if path == current_path do
      "bg-gray-900 text-white"
    else
      ""
    end
  end

  def active_live_class(conn, path) do
    if path == conn.host_uri do
      "bg-gray-900 text-white"
    else
      ""
    end
  end

  def active_link(%Plug.Conn{} = conn, text, opts) do
    class = [opts[:class], active_class(conn, opts[:to])]
            |> Enum.filter(& &1)
            |> Enum.join(" ")
    opts = opts
           |> Keyword.put(:class, class)
    link(text, opts)
  end

  def active_link(%Phoenix.LiveView.Socket{} = conn, text, opts) do
    class = [opts[:class], active_live_class(conn, opts[:to])]
            |> Enum.filter(& &1)
            |> Enum.join(" ")
    opts = opts
           |> Keyword.put(:class, class)
    live_patch(text, opts)
  end

end
