defmodule Claper.UtilFixture do
  defmacro merge_preload(origin, preload, assoc) do
    quote do
      unquote(origin) |>
      Map.merge(for p <- unquote(preload), unquote(assoc)[p], into: %{}, do: {p, unquote(assoc)[p]})
    end
  end
end
