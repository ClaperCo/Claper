defmodule ClaperWeb.PostControllerTest do
  use ClaperWeb.ConnCase, async: true

  import Claper.PresentationsFixtures

  # The action has no route, so it is called directly here. It still has to
  # answer every result the context can return instead of raising.
  describe "create/2" do
    test "answers a refused post instead of crashing", %{conn: conn} do
      presentation_file = presentation_file_fixture(%{}, [:event])

      presentation_state_fixture(%{
        presentation_file: presentation_file,
        chat_enabled: true,
        authenticated_chat_only: true
      })

      conn =
        ClaperWeb.PostController.create(conn, %{
          "event_id" => presentation_file.event.id,
          "body" => "a message without an author"
        })

      assert %{"errors" => %{"user_id" => ["must be logged in to post a message"]}} =
               json_response(conn, 422)

      assert Claper.Posts.list_posts(presentation_file.event.uuid) == []
    end
  end
end
