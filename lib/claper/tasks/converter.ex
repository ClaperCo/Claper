defmodule Claper.Tasks.Converter do
  @moduledoc """
  This module is used to convert presentations from PDF or PPT to images.
  We use a hash to identify the presentation. A new hash is generated when the conversion is finished and the presentation is being uploaded.
  """

  alias Claper.Events
  alias Porcelain.Result

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
    |> jpg_upload(hash, path, presentation, user_id, is_copy, ext_atom)
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

  defp jpg_upload(%Result{status: 0}, hash, path, presentation, user_id, is_copy, ext_atom) do
    files = Path.wildcard("#{path}/*.jpg")

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
    end

    if !is_nil(presentation.hash) && !is_copy do
      clear(presentation.hash)
    end

    success(presentation, path, new_hash, length(files), user_id, ext_atom)
  end

  defp jpg_upload(_result, _hash, path, presentation, user_id, _is_copy, _ext_atom) do
    failure(presentation, path, user_id)
  end

  defp success(presentation, path, hash, length, user_id, ext_atom) do
    with {:ok, presentation} <-
           Claper.Presentations.update_presentation_file(presentation, %{
             "hash" => "#{hash}",
             "length" => length,
             "status" => "done"
           }) do
      # For local storage the directory was already renamed to the new hash,
      # so original.pptx lives under the new hash path.
      # For S3 storage the original directory (path) is still intact at this point.
      pptx_path =
        if get_presentation_storage() == "local" do
          Path.join([get_presentation_storage_dir(), "uploads", "#{hash}", "original.pptx"])
        else
          "#{path}/original.pptx"
        end

      extract_and_save_notes(pptx_path, ext_atom, presentation.id, length)

      if get_presentation_storage() != "local", do: File.rm_rf!(path)

      Events.broadcast_user_events(user_id, {:presentation_file_process_done, presentation})
    end
  end

  defp extract_and_save_notes(pptx_path, :pptx, presentation_file_id, slide_count) do
    case :zip.unzip(String.to_charlist(pptx_path), [:memory]) do
      {:ok, files} ->
        for i <- 1..slide_count do
          filename = String.to_charlist("ppt/notesSlides/notesSlide#{i}.xml")

          case List.keyfind(files, filename, 0) do
            {_, content} ->
              html = extract_notes_html(content)

              if html != "" do
                Claper.Presentations.upsert_note(presentation_file_id, i - 1, html)
              end

            nil ->
              :ok
          end
        end

      _ ->
        :ok
    end
  end

  defp extract_and_save_notes(_path, _ext, _presentation_file_id, _slide_count), do: :ok

  # Extracts the notes body from a notesSlide XML and converts it to
  # an HTML string suitable for Quill. Each PPTX paragraph becomes a
  # <p> element, preserving line breaks and paragraph structure.
  defp extract_notes_html(xml_content) do
    import SweetXml

    paragraphs =
      xpath(
        xml_content,
        ~x"//*[local-name()='sp'][.//*[local-name()='ph'][@type='body']]//*[local-name()='txBody']/*[local-name()='p']"l
      )

    html =
      Enum.map_join(paragraphs, "", fn para ->
        runs = xpath(para, ~x".//*[local-name()='t']/text()"ls)
        text = Enum.join(runs, "")

        if String.trim(text) == "" do
          "<p><br></p>"
        else
          "<p>#{escape_html(text)}</p>"
        end
      end)

    if html == "", do: "", else: html
  rescue
    _ -> ""
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
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
end
