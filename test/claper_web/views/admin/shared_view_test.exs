defmodule ClaperWeb.Admin.SharedViewTest do
  use ClaperWeb.ConnCase, async: true

  # Import Phoenix.LiveViewTest for testing LiveView components
  import Phoenix.LiveViewTest
  import Phoenix.Component

  alias ClaperWeb.Admin.SharedView

  describe "modal component" do
    test "renders modal with content" do
      assigns = %{
        id: "test-modal",
        title: "Test Modal",
        show: true,
        return_to: "/admin"
      }

      content = ~H"""
      <div class="modal-content">Test Content</div>
      """

      html = render_component(SharedView, "modal.html", Map.put(assigns, :inner_content, content))

      assert html =~ "test-modal"
      assert html =~ "Test Modal"
      assert html =~ "Test Content"
      assert html =~ "modal-container"
      assert html =~ "modal-header"
      assert html =~ "modal-content"
    end

    test "modal is hidden when show is false" do
      assigns = %{
        id: "test-modal",
        title: "Test Modal",
        show: false,
        return_to: "/admin"
      }

      content = ~H"""
      <div class="modal-content">Test Content</div>
      """

      html = render_component(SharedView, "modal.html", Map.put(assigns, :inner_content, content))

      assert html =~ "hidden"
    end
  end

  describe "table component" do
    test "renders table with headers and rows" do
      assigns = %{
        headers: ["Name", "Email", "Role"],
        rows: [
          ["John Doe", "john@example.com", "Admin"],
          ["Jane Smith", "jane@example.com", "User"]
        ],
        id: "test-table"
      }

      html = render_component(SharedView, "table.html", assigns)

      assert html =~ "test-table"
      assert html =~ "Name"
      assert html =~ "Email"
      assert html =~ "Role"
      assert html =~ "John Doe"
      assert html =~ "john@example.com"
      assert html =~ "Admin"
      assert html =~ "Jane Smith"
      assert html =~ "jane@example.com"
      assert html =~ "User"
    end

    test "renders empty table message when no rows" do
      assigns = %{
        headers: ["Name", "Email", "Role"],
        rows: [],
        id: "empty-table",
        empty_message: "No data available"
      }

      html = render_component(SharedView, "table.html", assigns)

      assert html =~ "empty-table"
      assert html =~ "No data available"
    end
  end

  describe "search component" do
    test "renders search form with proper attributes" do
      assigns = %{
        search_path: "/admin/users",
        placeholder: "Search users...",
        search_term: "john"
      }

      html = render_component(SharedView, "search.html", assigns)

      assert html =~ "search-form"
      assert html =~ "Search users..."
      assert html =~ "value=\"john\""
      assert html =~ "action=\"/admin/users\""
    end
  end

  describe "form_field component" do
    test "renders text input field" do
      assigns = %{
        form: Phoenix.HTML.FormData.to_form(%Phoenix.HTML.Form{}, []),
        field: :name,
        label: "Name",
        type: "text",
        required: true
      }

      html = render_component(SharedView, "form_field.html", assigns)

      assert html =~ "form-group"
      assert html =~ "Name"
      assert html =~ "required"
      assert html =~ "type=\"text\""
    end

    test "renders field with error" do
      form =
        Phoenix.HTML.FormData.to_form(
          %Phoenix.HTML.Form{
            errors: [name: {"can't be blank", []}]
          },
          []
        )

      assigns = %{
        form: form,
        field: :name,
        label: "Name",
        type: "text",
        required: true
      }

      html = render_component(SharedView, "form_field.html", assigns)

      assert html =~ "form-group"
      assert html =~ "Name"
      assert html =~ "error-text"
      assert html =~ "can&#39;t be blank"
    end
  end

  describe "breadcrumbs component" do
    test "renders breadcrumbs with proper links" do
      assigns = %{
        breadcrumbs: [
          %{title: "Dashboard", path: "/admin"},
          %{title: "Users", path: "/admin/users"},
          %{title: "Edit User", active: true}
        ]
      }

      html = render_component(SharedView, "breadcrumbs.html", assigns)

      assert html =~ "breadcrumbs"
      assert html =~ "Dashboard"
      assert html =~ "Users"
      assert html =~ "Edit User"
      assert html =~ "href=\"/admin\""
      assert html =~ "href=\"/admin/users\""
      assert html =~ "active-breadcrumb"
    end
  end

  describe "flash component" do
    test "renders info flash message" do
      assigns = %{
        flash: %{"info" => "Operation successful"}
      }

      html = render_component(SharedView, "flash.html", assigns)

      assert html =~ "flash-container"
      assert html =~ "flash-info"
      assert html =~ "Operation successful"
    end

    test "renders error flash message" do
      assigns = %{
        flash: %{"error" => "Operation failed"}
      }

      html = render_component(SharedView, "flash.html", assigns)

      assert html =~ "flash-container"
      assert html =~ "flash-error"
      assert html =~ "Operation failed"
    end
  end
end
