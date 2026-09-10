defmodule ClaperWeb.PostController do
  use ClaperWeb, :controller

  def index(conn, %{"event_id" => event_id}) do
    try do
      with event <- Claper.Events.get_event!(event_id),
           posts <- Claper.Posts.list_posts(event.uuid, [:user, :attendee]) do
        render(conn, "index.json", posts: posts)
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(ClaperWeb.ErrorView)
        |> render(:"404")
    end
  end

  def create(conn, %{"event_id" => event_id, "body" => body}) do
    try do
      with event <- Claper.Events.get_event!(event_id) do
        case Claper.Posts.create_post(event, %{body: body}) do
          {:ok, post} ->
            render(conn, "post.json", post: post)

          {:error, %Ecto.Changeset{} = changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: translate_errors(changeset)})
        end
      end
    rescue
      Ecto.NoResultsError ->
        conn
        |> put_status(:not_found)
        |> put_view(ClaperWeb.ErrorView)
        |> render(:"404")
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &ClaperWeb.ErrorHelpers.translate_error/1)
  end
end
