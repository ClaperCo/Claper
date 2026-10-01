defmodule Claper.Tasks.Converter do
  @moduledoc """
  This module is used to convert presentations from PDF or PPT to images.
  We use a hash to identify the presentation. A new hash is generated when the conversion is finished and the presentation is being uploaded.
  """

  alias Claper.Events
  alias Claper.Presentations.PresentationFile
  alias Porcelain.Result

  @imagemagick_commands ~w(magick convert convert-im6.q16)

  @doc """
  Convert the presentation file to images.
  We use original hash :erlang.phash2(code-name) where the files are uploaded to send it to another folder with a new hash. This last stored in db.
  """
  def convert(user_id, file, hash, ext, presentation_file_id, is_copy \\ false) do
    presentation = Claper.Presentations.get_presentation_file!(presentation_file_id, [:event])

    {:ok, presentation} =
      Claper.Presentations.update_presentation_file(presentation, %{
        "status" => "progress"
      })

    Events.broadcast_user_events(user_id, {:presentation_file_process_done, presentation})

    path =
      Path.join([
        get_presentation_storage_dir(),
        "uploads",
        "#{hash}"
      ])

    IO.puts("Starting conversion for #{hash}... (copy: #{is_copy})")

    ext_atom =
      case ext do
        "ppt" -> :ppt
        "pptx" -> :pptx
        other -> other
      end

    file_to_pdf(ext_atom, path, file)
    |> pdf_to_jpg(path, presentation, user_id)
    |> jpg_upload(hash, path, presentation, user_id, is_copy)
  end

  @doc """
  Remove the presentation files directory
  """
  def clear(hash) do
    if get_presentation_storage() == "local" do
      File.rm_rf(
        Path.join([
          get_presentation_storage_dir(),
          "uploads",
          "#{hash}"
        ])
      )
    else
      stream =
        ExAws.S3.list_objects(get_s3_bucket(), prefix: "presentations/#{hash}")
        |> ExAws.stream!()
        |> Stream.map(& &1.key)

      ExAws.S3.delete_all_objects(get_s3_bucket(), stream) |> ExAws.request()
    end
  end

  @doc """
  Regenerates thumbnails for an already converted presentation.
  """
  def regenerate_thumbnails(%PresentationFile{hash: nil}), do: {:error, :missing_hash}
  def regenerate_thumbnails(%PresentationFile{length: nil}), do: {:error, :missing_length}
  def regenerate_thumbnails(%PresentationFile{length: 0}), do: {:error, :missing_length}

  def regenerate_thumbnails(%PresentationFile{hash: hash, length: length}) do
    case get_presentation_storage() do
      "local" ->
        path = Path.join([get_presentation_storage_dir(), "uploads", hash])
        generate_thumbnails(path)

      "s3" ->
        regenerate_s3_thumbnails(hash, length)

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  end

  defp file_to_pdf(:ppt, path, file) do
    Porcelain.exec(
      get_libreoffice_binary(),
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
      get_libreoffice_binary(),
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
    resolution = get_resolution()

    result =
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

    case result do
      %Porcelain.Result{status: 0} ->
        case generate_thumbnails(path) do
          :ok -> result
          _ -> %Porcelain.Result{status: 1}
        end

      _ ->
        result
    end
  end

  defp pdf_to_jpg(_result, path, presentation, user_id) do
    failure(presentation, path, user_id)
  end

  defp generate_thumbnails(path) do
    thumbs_dir = Path.join(path, "thumbs")
    File.rm_rf!(thumbs_dir)
    File.mkdir_p!(thumbs_dir)

    files = Path.wildcard("#{path}/*.jpg")

    with [_ | _] <- files,
         {:ok, imagemagick_command} <- get_imagemagick_command() do
      result =
        Enum.reduce_while(files, :ok, fn file, _acc ->
          generate_thumbnail(file, thumbs_dir, imagemagick_command)
        end)

      if result == :ok do
        IO.puts("Generated #{length(files)} thumbnails in #{thumbs_dir}")
      end

      result
    else
      [] -> {:error, :missing_slides}
      {:error, _reason} = error -> error
    end
  end

  defp generate_thumbnail(file, thumbs_dir, imagemagick_command) do
    thumb_path = Path.join(thumbs_dir, Path.basename(file))

    case Porcelain.exec(
           imagemagick_command,
           [
             file,
             "-resize",
             "200x",
             "-quality",
             "80",
             thumb_path
           ]
         ) do
      %Porcelain.Result{status: 0} -> {:cont, :ok}
      error -> {:halt, {:error, error}}
    end
  end

  defp get_imagemagick_command do
    case Enum.find(@imagemagick_commands, &System.find_executable/1) do
      nil -> {:error, :missing_imagemagick}
      command -> {:ok, command}
    end
  end

  defp jpg_upload(%Result{status: 0}, hash, path, presentation, user_id, is_copy) do
    files = Path.wildcard("#{path}/*.jpg")
    thumb_files = Path.wildcard("#{path}/thumbs/*.jpg")

    # assign new hash to avoid cache issues
    new_hash = :erlang.phash2("#{hash}-#{System.system_time(:second)}")

    if get_presentation_storage() == "local" do
      File.rename(
        Path.join([
          get_presentation_storage_dir(),
          "uploads",
          "#{hash}"
        ]),
        Path.join([
          get_presentation_storage_dir(),
          "uploads",
          "#{new_hash}"
        ])
      )
    else
      # Upload full-size images
      for f <- files do
        IO.puts("Uploads #{f} to presentations/#{new_hash}/#{Path.basename(f)}")

        f
        |> ExAws.S3.Upload.stream_file()
        |> ExAws.S3.upload(
          get_s3_bucket(),
          "presentations/#{new_hash}/#{Path.basename(f)}",
          acl: "public-read"
        )
        |> ExAws.request()
      end

      # Upload thumbnails
      for f <- thumb_files do
        IO.puts("Uploads thumbnail #{f} to presentations/#{new_hash}/thumbs/#{Path.basename(f)}")

        f
        |> ExAws.S3.Upload.stream_file()
        |> ExAws.S3.upload(
          get_s3_bucket(),
          "presentations/#{new_hash}/thumbs/#{Path.basename(f)}",
          acl: "public-read"
        )
        |> ExAws.request()
      end
    end

    if !is_nil(presentation.hash) && !is_copy do
      clear(presentation.hash)
    end

    success(presentation, path, new_hash, length(files), user_id)
  end

  defp jpg_upload(_result, _hash, path, presentation, user_id, _is_copy) do
    failure(presentation, path, user_id)
  end

  defp success(presentation, path, hash, length, user_id) do
    with {:ok, presentation} <-
           Claper.Presentations.update_presentation_file(presentation, %{
             "hash" => "#{hash}",
             "length" => length,
             "status" => "done",
             "slide_order" => nil
           }) do
      if get_presentation_storage() != "local", do: File.rm_rf!(path)

      Events.broadcast_user_events(user_id, {:presentation_file_process_done, presentation})
    end
  end

  defp failure(presentation, path, user_id) do
    with {:ok, presentation} <-
           Claper.Presentations.update_presentation_file(presentation, %{
             "status" => "fail"
           }) do
      File.rm_rf!(path)

      Events.broadcast_user_events(user_id, {:presentation_file_process_done, presentation})
    end
  end

  defp get_presentation_storage do
    Application.get_env(:claper, :presentations) |> Keyword.get(:storage)
  end

  defp get_presentation_storage_dir do
    Application.get_env(:claper, :storage_dir)
  end

  defp get_s3_bucket do
    Application.get_env(:claper, :presentations) |> Keyword.get(:s3_bucket)
  end

  defp get_resolution do
    Application.get_env(:claper, :presentations) |> Keyword.get(:resolution)
  end

  defp get_libreoffice_binary do
    case :os.type() do
      {:unix, :darwin} -> "soffice"
      _ -> "libreoffice"
    end
  end

  defp regenerate_s3_thumbnails(hash, length) do
    path =
      Path.join(System.tmp_dir!(), "claper-thumbs-#{hash}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(path)

    with :ok <- download_s3_slides(path, hash, length),
         :ok <- generate_thumbnails(path),
         :ok <- upload_s3_thumbnails(path, hash) do
      File.rm_rf!(path)
      :ok
    else
      error ->
        File.rm_rf!(path)
        error
    end
  end

  defp download_s3_slides(path, hash, length) do
    Enum.reduce_while(1..length, :ok, fn index, _acc ->
      key = "presentations/#{hash}/#{index}.jpg"

      case ExAws.S3.get_object(get_s3_bucket(), key) |> ExAws.request() do
        {:ok, %{body: body}} ->
          file_path = Path.join(path, "#{index}.jpg")
          File.write!(file_path, body, [:binary])
          {:cont, :ok}

        error ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp upload_s3_thumbnails(path, hash) do
    path
    |> Path.join("thumbs/*.jpg")
    |> Path.wildcard()
    |> Enum.reduce_while(:ok, fn file, _acc ->
      key = "presentations/#{hash}/thumbs/#{Path.basename(file)}"

      case file
           |> ExAws.S3.Upload.stream_file()
           |> ExAws.S3.upload(get_s3_bucket(), key, acl: "public-read")
           |> ExAws.request() do
        {:ok, _response} -> {:cont, :ok}
        error -> {:halt, {:error, error}}
      end
    end)
  end
end
