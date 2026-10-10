defmodule ClaperWeb.StatControllerTest do
  use ClaperWeb.ConnCase, async: true

  import Claper.{AccountsFixtures, FormsFixtures, PresentationsFixtures, ScalesFixtures}

  describe "export_transcriptions/2" do
    test "exports timestamp, language, and text as CSV", %{conn: conn} do
      user = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: user}, [:event])

      {:ok, transcription} =
        Claper.Transcriptions.create_transcription(%{
          presentation_file_id: presentation_file.id,
          language: "en",
          text: "Welcome to the event"
        })

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/export/#{presentation_file.event.uuid}/transcriptions")

      assert response(conn, 200) =~
               "Timestamp (UTC),Language,Text\r\n#{Calendar.strftime(transcription.inserted_at, "%Y-%m-%d %H:%M:%S")},en,Welcome to the event"
    end

    test "rejects users without access", %{conn: conn} do
      owner = confirmed_user_fixture()
      unauthorized_user = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      conn =
        conn
        |> log_in_user(unauthorized_user)
        |> post(~p"/export/#{presentation_file.event.uuid}/transcriptions")

      assert response(conn, 403) == "Forbidden"
    end
  end

  describe "POST /export/forms/:form_id" do
    setup %{conn: conn} do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      form =
        form_fixture(%{
          presentation_file_id: presentation_file.id,
          title: "My Form",
          fields: [
            %{name: "First Name", type: "text", required: false},
            %{name: "Email Address", type: "email", required: false}
          ]
        })

      %{conn: log_in_user(conn, owner), form: form, event: presentation_file.event}
    end

    test "exports CSV with field names containing spaces as headers and values", %{
      conn: conn,
      form: form,
      event: event
    } do
      {:ok, _submit} =
        Claper.Forms.create_or_update_form_submit(event.uuid, %{
          "attendee_identifier" => "attendee-1",
          "form_id" => form.id,
          "response" => %{"First Name" => "Ada", "Email Address" => "ada@example.com"}
        })

      conn = post(conn, ~p"/export/forms/#{form.id}")

      assert response_content_type(conn, :csv)
      body = response(conn, 200)

      [header_line, data_line | _] = String.split(body, "\r\n", trim: true)

      assert header_line =~ "First Name"
      assert header_line =~ "Email Address"

      assert data_line =~ "Ada"
      assert data_line =~ "ada@example.com"
    end

    test "returns 403 for users who don't own the event", %{form: form} do
      stranger = confirmed_user_fixture()
      conn = build_conn() |> log_in_user(stranger)

      conn = post(conn, ~p"/export/forms/#{form.id}")

      assert response(conn, 403) == "Forbidden"
    end
  end

  describe "POST /export/scales/:scale_id" do
    setup %{conn: conn} do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      scale =
        scale_fixture(%{
          presentation_file: presentation_file,
          title: "How sure are you?",
          min_value: -2,
          max_value: 2
        })

      %{
        conn: log_in_user(conn, owner),
        owner: owner,
        scale: scale,
        event: presentation_file.event
      }
    end

    test "exports one row per response with the value as a number", %{
      conn: conn,
      owner: owner,
      scale: scale,
      event: event
    } do
      {:ok, _} = Claper.Scales.submit_response(event.uuid, scale, "attendee-1", "-2")
      {:ok, _} = Claper.Scales.submit_response(event.uuid, scale, owner.id, "1")

      conn = post(conn, ~p"/export/scales/#{scale.id}")

      assert response_content_type(conn, :csv)

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="slider-How-sure-are-you.csv")
             ]

      [header_line, attendee_line, user_line] =
        conn |> response(200) |> String.split("\r\n", trim: true)

      assert header_line == "Attendee identifier,User email,Value,Answered at (UTC)"
      assert attendee_line =~ ~r/^#{Base.encode16("attendee-1")},N\/A,-2,\d{4}-\d{2}-\d{2}/
      assert user_line =~ "N/A,#{owner.email},1,"
    end

    test "exports only the header when nobody has answered", %{conn: conn, scale: scale} do
      conn = post(conn, ~p"/export/scales/#{scale.id}")

      assert conn |> response(200) |> String.split("\r\n", trim: true) == [
               "Attendee identifier,User email,Value,Answered at (UTC)"
             ]
    end

    test "returns 403 for users who don't own the event", %{scale: scale} do
      stranger = confirmed_user_fixture()
      conn = build_conn() |> log_in_user(stranger)

      conn = post(conn, ~p"/export/scales/#{scale.id}")

      assert response(conn, 403) == "Forbidden"
    end
  end
end
