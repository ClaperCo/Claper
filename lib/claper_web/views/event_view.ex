defmodule ClaperWeb.EventView do
  use ClaperWeb, :view

  def render("show.json", %{event: event}) do
    %{data: render_one(event, ClaperWeb.EventView, "event.json")}
  end

  def render("event.json", %{event: event}) do
    %{
      uuid: event.uuid,
      name: event.name,
      posts: render_many(event.posts, ClaperWeb.PostView, "post.json")
    }
  end
end
