defmodule ClaperWeb.EventLive.EventFormComponent do
  alias Claper.Presentations.PresentationFile
  use ClaperWeb, :live_component

  alias Claper.Events

  @impl true
  def update(%{event: event} = assigns, socket) do
    changeset = Events.change_event(event)

    max_file_size = get_max_file_size()

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:changeset, changeset)
     |> assign(:max_file_size, max_file_size)
     |> allow_upload(:presentation_file,
       accept: ~w(.pdf .ppt .pptx),
       auto_upload: true,
       max_entries: 1,
       # MB
       max_file_size: max_file_size * 1_000_000
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
        Events.change_activity_leader(%Events.ActivityLeader{
          temp_id: get_temp_id()
        })
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
      case leaders do
        [] -> Events.change_event(socket.assigns.event, %{leaders: leaders})
        _ -> socket.assigns.changeset |> Ecto.Changeset.put_assoc(:leaders, leaders)
      end

    {:noreply, assign(socket, changeset: changeset)}
  end

  defp get_temp_id, do: :crypto.strong_rand_bytes(5) |> Base.url_encode64() |> binary_part(0, 5)

  defp save_file(socket, %{"code" => code, "name" => name} = event_params, after_save) do
    hash = :erlang.phash2("#{code}-#{name}")

    static_path =
      Path.join([
        get_presentation_storage_dir(),
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

            # The storage directory must exist for `File.cp!/2` to work.
            File.mkdir_p!(static_path)

            File.cp!(path, dest)

            {:ok, "/uploads/#{hash}/#{Path.basename(dest)}"}
          end)

        [ext | _] = MIME.extensions(MIME.from_path(dest))

        if Map.has_key?(socket.assigns.event.presentation_file, :id) do
          after_save.(
            socket,
            event_params,
            hash,
            ext
          )
        else
          after_save.(
            socket,
            Map.put(event_params, "presentation_file", %{
              "status" => "progress",
              "presentation_state" => %{}
            }),
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

  defp save_event(
         %{assigns: %{event: %{:presentation_file => %PresentationFile{}}}} = socket,
         :new,
         event_params
       ) do
    save_file(socket, event_params, &create_event/4)
  end

  defp save_event(
         %{assigns: %{event: %{:presentation_file => %Ecto.Association.NotLoaded{}}}} = socket,
         :new,
         event_params
       ) do
    case uploaded_entries(socket, :presentation_file) do
      {[_ | _], []} -> save_file(socket, event_params, &create_event/4)
      _ -> create_event(socket, event_params)
    end
  end

  defp create_event(socket, event_params) do
    case Events.create_event(
           event_params
           |> Map.put("user_id", socket.assigns.current_user.id)
           |> Map.put("presentation_file", %{
             "status" => "done",
             "length" => 0,
             "presentation_state" => %{}
           })
         ) do
      {:ok, event} ->
        with e <- Events.get_event!(event.uuid, [:leaders]) do
          Enum.each(e.leaders, fn leader ->
            Claper.Accounts.LeaderNotifier.deliver_event_invitation(
              e.name,
              leader.email,
              url(~p"/events")
            )
          end)
        end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Created successfully"))
         |> redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp create_event(socket, event_params, hash, ext) do
    case Events.create_event(
           event_params
           |> Map.put("user_id", socket.assigns.current_user.id)
         ) do
      {:ok, event} ->
        with e <- Events.get_event!(event.uuid, [:presentation_file, :leaders]) do
          Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
            Claper.Tasks.Converter.convert(
              socket.assigns.current_user.id,
              "original.#{ext}",
              hash,
              ext,
              e.presentation_file.id
            )
          end)

          Enum.each(e.leaders, fn leader ->
            Claper.Accounts.LeaderNotifier.deliver_event_invitation(
              e.name,
              leader.email,
              url(~p"/events")
            )
          end)
        end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Created successfully"))
         |> redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  defp edit_event(socket, event_params, hash, ext) do
    case Events.update_event(
           socket.assigns.event,
           event_params
         ) do
      {:ok, event} ->
        handle_file_conversion(socket, hash, ext, event)

        send_email_to_leaders(socket, event)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Updated successfully"))
         |> redirect(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  defp handle_file_conversion(socket, hash, ext, event) do
    if is_nil(hash) || is_nil(ext) do
      :ok
    else
      files = Claper.Presentations.get_presentation_files_by_hash(event.presentation_file.hash)

      Task.Supervisor.async_nolink(Claper.TaskSupervisor, fn ->
        Claper.Tasks.Converter.convert(
          socket.assigns.current_user.id,
          "original.#{ext}",
          hash,
          ext,
          socket.assigns.event.presentation_file.id,
          files |> Enum.count() > 1
        )
      end)
    end
  end

  defp get_max_file_size() do
    Application.get_env(:claper, :presentations) |> Keyword.get(:max_file_size)
  end

  defp get_presentation_storage_dir do
    Application.get_env(:claper, :storage_dir)
  end

  defp send_email_to_leaders(socket, event) do
    with e <- Events.get_event!(event.uuid, [:leaders]) do
      # Get the leaders before the update
      previous_leaders = socket.assigns.event.leaders

      Enum.each(e.leaders, fn leader ->
        # Only send email if leader was not present before the update
        unless Enum.member?(previous_leaders, leader) do
          Claper.Accounts.LeaderNotifier.deliver_event_invitation(
            e.name,
            leader.email,
            url(~p"/events")
          )
        end
      end)
    end
  end

  def error_to_string(:too_large), do: gettext("Your file is too large")
  def error_to_string(:not_accepted), do: gettext("You have selected an incorrect file type")
  def error_to_string(:external_client_failure), do: gettext("Upload failed")
end
