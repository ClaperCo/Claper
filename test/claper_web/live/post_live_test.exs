defmodule ClaperWeb.PostLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, PostsFixtures}

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    post = post_fixture(%{user: params.user, event: presentation_file.event})
    params |> Map.put(:presentation_file, presentation_file) |> Map.put(:post, post)
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_event]

    test "list posts", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _index_live, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}")

      assert html =~ "some body"
    end
  end
end
