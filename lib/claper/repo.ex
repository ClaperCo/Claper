defmodule Claper.Repo do
  use Ecto.Repo,
    otp_app: :claper,
    adapter: Ecto.Adapters.Postgres

  import Ecto.Query

  @default_page_size 12

  def init(_type, config) do
    if url = System.get_env("DATABASE_URL") do
      {:ok, Keyword.put(config, :url, url)}
    else
      {:ok, config}
    end
  end

  def paginate(query, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, @default_page_size)
    preload = Keyword.get(opts, :preload, [])

    total_entries =
      query
      |> exclude(:order_by)
      |> exclude(:preload)
      |> exclude(:select)
      |> select(count("*"))
      |> Claper.Repo.one()

    total_pages = ceil(total_entries / page_size)

    results =
      query
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Claper.Repo.all()
      |> Claper.Repo.preload(preload)

    {results, total_entries, total_pages}
  end
end
