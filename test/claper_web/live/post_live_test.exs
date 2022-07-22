defmodule ClaperWeb.PostLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.PostsFixtures

  @create_attrs %{body: "some body"}
  @update_attrs %{body: "some updated body"}
  @invalid_attrs %{body: nil}

  defp create_post(params) do
    post = post_fixture(%{}, [:room])
    params |> Map.put(:post, post) |> Map.put(:org_id, post.org_id)
  end

  describe "Index" do
    setup [:create_post, :register_and_log_in_user]

    test "lists all posts", %{conn: conn, post: post} do
      {:ok, _index_live, html} = live(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert html =~ "Listing Posts"
      assert html =~ post.body
    end

    test "saves new post", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert index_live |> element("a", "New Post") |> render_click() =~
               "New Post"

      assert_patch(index_live, Routes.post_index_path(conn, :new, post.room.uuid))

      assert index_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#post-form", post: @create_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert html =~ "Post created successfully"
      assert html =~ "some body"
    end

    test "updates post in listing", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert index_live |> element("#post-#{post.uuid} a", "Edit") |> render_click() =~
               "Edit Post"

      assert_patch(index_live, Routes.post_index_path(conn, :edit, post.uuid))

      assert index_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        index_live
        |> form("#post-form", post: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert html =~ "Post updated successfully"
      assert html =~ "some updated body"
    end

    test "deletes post in listing", %{conn: conn, post: post} do
      {:ok, index_live, _html} = live(conn, Routes.post_index_path(conn, :index, post.room.uuid))

      assert index_live |> element("#post-#{post.uuid} a", "Delete") |> render_click()
      refute index_live |> element("#post-#{post.uuid} a", "Delete") |> has_element?
    end
  end

  describe "Show" do
    setup [:create_post, :register_and_log_in_user]

    test "displays post", %{conn: conn, post: post} do
      {:ok, _show_live, html} = live(conn, Routes.post_show_path(conn, :show, post.uuid))

      assert html =~ "Show Post"
      assert html =~ post.body
    end

    test "updates post within modal", %{conn: conn, post: post} do
      {:ok, show_live, _html} = live(conn, Routes.post_show_path(conn, :show, post.uuid))

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit Post"

      assert_patch(show_live, Routes.post_show_path(conn, :edit, post.uuid))

      assert show_live
             |> form("#post-form", post: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _, html} =
        show_live
        |> form("#post-form", post: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, Routes.post_show_path(conn, :show, post.uuid))

      assert html =~ "Post updated successfully"
      assert html =~ "some updated body"
    end
  end
end
