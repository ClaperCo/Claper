defmodule Claper.Repo do
  use Ecto.Repo,
    otp_app: :claper,
    adapter: Ecto.Adapters.Postgres

  def init(_type, config) do
    if url = System.get_env("DATABASE_URL") do
      {:ok, Keyword.put(config, :url, url)}
    else
      {:ok, config}
    end
  end
end
