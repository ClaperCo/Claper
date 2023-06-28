defmodule Claper.Tasks.Converter do
  @moduledoc """
  This module is used to convert presentations from PDF or PPT to images.
  We use a hash to identify the presentation. A new hash is generated when the conversion is finished and the presentation is being uploaded.
  """

  alias ExAws.S3
  alias Porcelain.Result

  @doc """
  Convert the presentation file to images.
  We use original hash :erlang.phash2(code-name) where the files are uploaded to send it to another folder with a new hash. This last stored in db.
  """
  def convert(user_id, file, hash, ext, presentation_file_id) do
    presentation = Claper.Presentations.get_presentation_file!(presentation_file_id, [:event])

    {:ok, presentation} =
      Claper.Presentations.update_presentation_file(presentation, %{
        "status" => "progress"
      })

    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "events:#{user_id}",
      {:presentation_file_process_done, presentation}
    )

    path =
      Path.join([
        :code.priv_dir(:claper),
        "static",
        "uploads",
        "#{hash}"
      ])

    IO.puts("Starting conversion for #{hash}...")

    file_to_pdf(String.to_atom(ext), path, file)
    |> pdf_to_jpg(path, presentation, user_id)
    |> jpg_upload(hash, path, presentation, user_id)
  end

  @doc """
  Remove the presentation files directory
  """
  def clear(hash) do
    IO.puts("Clearing #{hash}...")

    if System.get_env("PRESENTATION_STORAGE", "local") == "local" do
      File.rm_rf(
        Path.join([
          :code.priv_dir(:claper),
          "static",
          "uploads",
          "#{hash}"
        ])
      )
    else
      stream =
        ExAws.S3.list_objects(System.get_env("AWS_PRES_BUCKET"), prefix: "presentations/#{hash}")
        |> ExAws.stream!()
        |> Stream.map(& &1.key)

      ExAws.S3.delete_all_objects(System.get_env("AWS_PRES_BUCKET"), stream) |> ExAws.request()
    end
  end

  defp file_to_pdf(:ppt, path, file) do
    Porcelain.exec(
      "libreoffice",
      [
        "--headless",
        "--invisible",
        "--convert-to",
        "pdf",
        "--outdir",
        path,
        "#{path}/#{file}"
      ]
    )
  end

  defp file_to_pdf(:pptx, path, file) do
    Porcelain.exec(
      "libreoffice",
      [
        "--headless",
        "--invisible",
        "--convert-to",
        "pdf",
        "--outdir",
        path,
        "#{path}/#{file}"
      ]
    )
  end

  defp file_to_pdf(_ext, _path, _file), do: %Result{status: 0}

  defp pdf_to_jpg(%Result{status: 0}, path, _presentation, _user_id) do
    resolution = System.get_env("GS_JPG_RESOLUTION", "300x300")
    Porcelain.exec(
      "gs",
      [
        "-sDEVICE=png16m",
        "-o#{path}/%d.jpg",
        "-r#{resolution}",
        "-dNOPAUSE",
        "-dBATCH",
        "#{path}/original.pdf"
      ]
    )
  end

  defp pdf_to_jpg(_result, path, presentation, user_id) do
    failure(presentation, path, user_id)
  end

  defp jpg_upload(%Result{status: 0}, hash, path, presentation, user_id) do
    files = Path.wildcard("#{path}/*.jpg")

    # assign new hash to avoid cache issues
    new_hash = :erlang.phash2("#{hash}-#{System.system_time(:second)}")

    if System.get_env("PRESENTATION_STORAGE", "local") == "local" do
      File.rename(
        Path.join([
          :code.priv_dir(:claper),
          "static",
          "uploads",
          "#{hash}"
        ]),
        Path.join([
          :code.priv_dir(:claper),
          "static",
          "uploads",
          "#{new_hash}"
        ])
      )
    else
      for f <- files do
        IO.puts("Uploads #{f} to presentations/#{new_hash}/#{Path.basename(f)}")

        f
        |> S3.Upload.stream_file()
        |> S3.upload(
          System.get_env("AWS_PRES_BUCKET"),
          "presentations/#{new_hash}/#{Path.basename(f)}",
          acl: "public-read"
        )
        |> ExAws.request()
      end
    end

    if !is_nil(presentation.hash) do
      clear(presentation.hash)
    end

    success(presentation, path, new_hash, length(files), user_id)
  end

  defp jpg_upload(_result, _hash, path, presentation, user_id) do
    failure(presentation, path, user_id)
  end

  defp success(presentation, path, hash, length, user_id) do
    with {:ok, presentation} <-
           Claper.Presentations.update_presentation_file(presentation, %{
             "hash" => "#{hash}",
             "length" => length,
             "status" => "done"
           }) do
      unless System.get_env("PRESENTATION_STORAGE", "local") == "local", do: File.rm_rf!(path)

      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "events:#{user_id}",
        {:presentation_file_process_done, presentation}
      )
    end
  end

  defp failure(presentation, path, user_id) do
    with {:ok, presentation} <-
           Claper.Presentations.update_presentation_file(presentation, %{
             "status" => "fail"
           }) do
      File.rm_rf!(path)

      Phoenix.PubSub.broadcast(
        Claper.PubSub,
        "events:#{user_id}",
        {:presentation_file_process_done, presentation}
      )
    end
  end
end
