defmodule ClaperWeb.Notifiers.EventNotifier do
  use Phoenix.Swoosh, view: ClaperWeb.EventNotifierView, layout: {ClaperWeb.LayoutView, :email}
  use Gettext, backend: ClaperWeb.Gettext
  use ClaperWeb, :verified_routes

  @doc """
  The recap of an ended event for its owner, with the figures of
  `Claper.Stats.report_summary/1`. `inactivity_days` is the delay after which the
  event was terminated for inactivity, or `nil` when its owner terminated it.
  """
  def recap(event, summary, inactivity_days) do
    new()
    |> to(event.user.email)
    |> from(
      {Application.get_env(:claper, :mail) |> Keyword.get(:from_name),
       Application.get_env(:claper, :mail) |> Keyword.get(:from)}
    )
    |> subject(gettext("Recap of your event %{name}", name: event.name))
    |> render_body("recap.html", %{
      event: event,
      summary: summary,
      inactivity_days: inactivity_days,
      url: url(~p"/events/#{event.uuid}/stats")
    })
  end
end
