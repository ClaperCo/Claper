defmodule Claper.DockerfileDevTest do
  use ExUnit.Case, async: true

  @dockerfile Path.expand("../Dockerfile.dev", __DIR__)

  test "development entrypoint bootstraps the database with seeds" do
    command = startup_command()

    assert command =~ "mix ecto.setup"
    refute command =~ "mix ecto.migrate"
    assert_before(command, "mix ecto.setup", "mix phx.server")
  end

  test "development entrypoint builds styles after npm install and before starting Phoenix" do
    command = startup_command()

    commands = [
      "npm i",
      "mix tailwind default",
      "mix tailwind admin",
      "mix sass default",
      "mix phx.server"
    ]

    commands
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [earlier, later] -> assert_before(command, earlier, later) end)
  end

  defp startup_command do
    dockerfile = File.read!(@dockerfile)

    assert [[command]] =
             Regex.scan(~r/^ENTRYPOINT \["bash", "-c", "([^"]+)"\]$/m, dockerfile,
               capture: :all_but_first
             )

    command
  end

  defp assert_before(command, earlier, later) do
    assert {earlier_position, _length} = :binary.match(command, earlier)
    assert {later_position, _length} = :binary.match(command, later)
    assert earlier_position < later_position
  end
end
