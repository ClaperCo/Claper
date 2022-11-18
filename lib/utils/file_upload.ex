defmodule Utils.FileUpload do
  import Mogrify

  def upload(type, path, old_path) when is_atom(type) do
    remove_old_file(old_path)

    dest =
      Path.join([
        :code.priv_dir(:claper),
        "static",
        "uploads",
        Atom.to_string(type),
        Path.basename(path)
      ])

    open(path) |> resize_to_fill("100x100") |> save(in_place: true)
    File.cp!(path, dest)
    "/uploads/#{Atom.to_string(type)}/#{Path.basename(dest)}"
  end

  defp remove_old_file(old_path) do
    if old_path do
      old_file = Path.join([:code.priv_dir(:claper), "static", old_path])
      if File.exists?(old_file), do: File.rm(old_file)
    end
  end
end
