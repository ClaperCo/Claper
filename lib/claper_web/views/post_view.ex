defmodule ClaperWeb.PostView do
  use ClaperWeb, :view

  def render("index.json", %{posts: posts}) do
    %{data: render_many(posts, ClaperWeb.PostView, "post.json")}
  end

  def render("post.json", %{post: %{user: %{uuid: _} = user} = post}) do
    %{
      uuid: post.uuid,
      body: post.body,
      inserted_at: post.inserted_at,
      user: render_one(user, ClaperWeb.UserView, "user.json")
    }
  end

  def render("post.json", %{post: %{attendee: %{uuid: _} = attendee} = post}) do
    %{
      uuid: post.uuid,
      body: post.body,
      inserted_at: post.inserted_at,
      attendee: render_one(attendee, ClaperWeb.AttendeeView, "attendee.json")
    }
  end
end
