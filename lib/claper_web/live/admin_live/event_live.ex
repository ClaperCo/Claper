defmodule ClaperWeb.AdminLive.EventLive do
  use ClaperWeb, :admin_live_view

  import ClaperWeb.AdminLive.DetailComponents

  alias Claper.Admin
  alias Claper.Events.Event

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    {events, meta} = Admin.list_events_paginated(params)

    socket
    |> assign(:page_title, gettext("Events"))
    |> assign(:event, nil)
    |> assign(:events, events)
    |> assign(:meta, meta)
    |> assign(:form, Phoenix.Component.to_form(meta))
    |> assign_new(:fields, fn ->
      [
        name: [
          label: nil,
          placeholder: gettext("Search events..."),
          type: "text",
          op: :ilike_or
        ]
      ]
    end)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, gettext("New event"))
    |> assign(:event, %Event{})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, gettext("Edit event"))
    |> assign(:event, Claper.Events.get_event!(id, [:user]))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    event = Claper.Events.get_event!(id, [:user])
    transcriptions = Admin.list_transcriptions_for_event(id)

    socket
    |> assign(:page_title, gettext("Event details"))
    |> assign(:event, event)
    |> assign(:transcriptions, transcriptions)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    event = Claper.Events.get_event!(id)

    case Claper.Events.delete_event(event) do
      {:ok, _event} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Event and all its data deleted permanently"))
         |> push_patch(to: ~p"/admin/events")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not delete event"))}
    end
  end

  @impl true
  def handle_event("filter-events", unsigned_params, socket) do
    flop = Flop.validate!(unsigned_params, for: Event, replace_invalid_params: true)
    to = Flop.Phoenix.build_path(~p"/admin/events", flop)

    {:noreply, push_patch(socket, to: to)}
  end

  @impl true
  def handle_event("delete_transcription", %{"id" => id}, socket) do
    id = String.to_integer(id)

    case Admin.delete_transcription(id) do
      {:ok, _} ->
        transcriptions = Admin.list_transcriptions_for_event(socket.assigns.event.id)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Transcription deleted"))
         |> assign(:transcriptions, transcriptions)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Could not delete transcription"))}
    end
  end

  @impl true
  def handle_event("export_transcriptions", _params, socket) do
    event = socket.assigns.event
    transcriptions = socket.assigns.transcriptions

    content =
      Enum.map_join(transcriptions, "\n", fn t ->
        "[#{Calendar.strftime(t.inserted_at, "%Y-%m-%d %H:%M:%S")}] #{t.text}"
      end)

    {:noreply,
     push_event(socket, "download_csv", %{
       filename: "transcription-#{event.code}.txt",
       content: content
     })}
  end
end
