defmodule ClaperWeb.EventLive.EventFormComponent do
  use ClaperWeb, :live_component

  alias Claper.Events

  @impl true
  def update(%{event: event} = assigns, socket) do
    changeset = Events.change_event(event)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> allow_upload(:presentation_file,
       accept: ~w(.pdf .ppt .pptx),
       auto_upload: true,
       max_entries: 1,
       max_file_size: 15_000_000
     )}
  end

  @impl true
  def handle_event("validate", %{"event" => event_params}, socket) do
    changeset =
      socket.assigns.event
      |> Events.change_event(event_params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("validate-file", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove-file", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :presentation_file, ref)}
  end

  @impl true
  def handle_event("save", %{"event" => event_params}, socket) do
    save_event(socket, socket.assigns.action, event_params)
  end

  @impl true
  def handle_event(
        "add-leader",
        _params,
        socket
      ) do
    existing_leaders =
      Map.get(socket.assigns.changeset.changes, :leaders, socket.assigns.event.leaders)

    leaders =
      existing_leaders
      |> Enum.concat([
        Events.change_activity_leader(%Events.ActivityLeader{temp_id: get_temp_id()})
      ])

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_assoc(:leaders, leaders)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event(
        "remove-leader",
        %{"remove" => remove_id},
        socket
      ) do
    leaders =
      socket.assigns.changeset.changes.leaders
      |> Enum.reject(fn %{data: leader} ->
        leader.temp_id == remove_id
      end)

    changeset =
      socket.assigns.changeset
      |> Ecto.Changeset.put_assoc(:leaders, leaders)

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp get_temp_id, do: :crypto.strong_rand_bytes(5) |> Base.url_encode64() |> binary_part(0, 5)

  defp save_file(socket, %{"code" => code, "name" => name} = event_params, after_save) do
    hash = :erlang.phash2("#{code}-#{name}")

    static_path =
      Path.join([
        :code.priv_dir(:claper),
        "static",
        "uploads",
        "#{hash}"
      ])

    case uploaded_entries(socket, :presentation_file) do
      {[_ | _], []} ->
        [dest | _] =
          consume_uploaded_entries(socket, :presentation_file, fn %{path: path}, entry ->
            [ext | _] = MIME.extensions(entry.client_type)

            dest =
              Path.join([
                static_path,
                "original.#{ext}"
              ])

            # The `static/uploads` directory must exist for `File.cp!/2` to work.
            File.mkdir_p!(static_path)

            File.cp!(path, dest)

            {:ok, Routes.static_path(socket, "/uploads/#{hash}/#{Path.basename(dest)}")}
          end)

        [ext | _] = MIME.extensions(MIME.from_path(dest))

        if !Map.has_key?(socket.assigns.event.presentation_file, :id) do
          after_save.(
            socket,
            Map.put(event_params, "presentation_file", %{
              "status" => "progress",
              "presentation_state" => %{}
            }),
            hash,
            ext
          )
        else
          after_save.(
            socket,
            event_params,
            hash,
            ext
          )
        end

      _ ->
        after_save.(socket, event_params, nil, nil)
    end
  end

  defp save_event(socket, :edit, event_params) do
    save_file(socket, event_params, &edit_event/4)
  end

  defp save_event(socket, :new, event_params) do
    save_file(socket, event_params, &create_event/4)
  end

  defp create_event(socket, event_params, hash, ext) do
    case Events.create_event(
           event_params
           |> Map.put("user_id", socket.assigns.current_user.id)
         ) do
      {:ok, event} ->
        with e <- Events.get_event!(event.uuid, [:presentation_file]) do
          Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
            Claper.Tasks.Converter.convert(
              socket.assigns.current_user.id,
              "original.#{ext}",
              hash,
              ext,
              e.presentation_file.id
            )
          end)
        end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Created successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp edit_event(socket, event_params, hash, ext) do
    case Events.update_event(
           socket.assigns.event,
           event_params
         ) do
      {:ok, _event} ->
        if !is_nil(hash) && !is_nil(ext) do
          Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
            Claper.Tasks.Converter.convert(
              socket.assigns.current_user.id,
              "original.#{ext}",
              hash,
              ext,
              socket.assigns.event.presentation_file.id
            )
          end)
        end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Updated successfully"))
         |> push_redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def error_to_string(:too_large), do: gettext("Your file is too large")
  def error_to_string(:not_accepted), do: gettext("You have selected an incorrect file type")
  def error_to_string(:external_client_failure), do: gettext("Upload failed")
end
