defmodule ClaperWeb.StatControllerTest do
  use ClaperWeb.ConnCase, async: true

  import Claper.{
    AccountsFixtures,
    FormsFixtures,
    PostsFixtures,
    PresentationsFixtures,
    QuizzesFixtures,
    WordCloudsFixtures
  }

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

  describe "POST /export/:event_id/messages" do
    test "protects message text and names while preserving numeric and boolean cells", %{
      conn: conn
    } do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      message =
        post_fixture(%{
          user: owner,
          event: presentation_file.event,
          name: "+Presenter",
          body: "=HYPERLINK(\"https://example.com\",\"click\")",
          position: 0
        })

      conn =
        conn
        |> log_in_user(owner)
        |> post(~p"/export/#{presentation_file.event.uuid}/messages")

      assert [headers, row] = CSV.decode!([response(conn, 200)]) |> Enum.to_list()

      assert headers == [
               "Attendee identifier",
               "User email",
               "Name",
               "Message",
               "Pinned",
               "Slide #",
               "Sent at (UTC)"
             ]

      assert row == [
               "N/A",
               owner.email,
               "'+Presenter",
               "'=HYPERLINK(\"https://example.com\",\"click\")",
               to_string(message.pinned),
               "1",
               to_string(message.inserted_at)
             ]
    end
  end

  describe "POST /export/quizzes/:quiz_id" do
    test "CSV totals match application scores for exact, partial, wrong, extra and missing answers",
         %{conn: conn} do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      quiz =
        quiz_fixture(%{
          presentation_file: presentation_file,
          enabled: true,
          quiz_questions: [
            %{
              content: "Select both correct options",
              type: "qcm",
              quiz_question_opts: [
                %{content: "A", is_correct: true},
                %{content: "B", is_correct: true},
                %{content: "C", is_correct: false}
              ]
            },
            %{
              content: "Second question",
              type: "qcm",
              quiz_question_opts: [%{content: "D", is_correct: true}]
            }
          ]
        })

      [multiple, second] = quiz.quiz_questions
      [a, b, c] = multiple.quiz_question_opts
      [d] = second.quiz_question_opts

      cases = [
        {owner, owner.id, [a, b], "A, B", 2},
        {"partial", "partial", [a], "A", 1},
        {"extra", "extra", [a, b, c], "A, B, C", 1},
        {"wrong", "wrong", [c], "C", 1},
        {"missing", "missing", [], "", 1}
      ]

      for {participant, _, selected, _, _} <- cases do
        assert {:ok, _} =
                 Claper.Quizzes.submit_quiz(
                   participant,
                   presentation_file.event.uuid,
                   selected ++ [d],
                   quiz.id
                 )
      end

      exported =
        conn
        |> log_in_user(owner)
        |> post(~p"/export/quizzes/#{quiz.id}")

      assert [headers | rows] = CSV.decode!([response(exported, 200)]) |> Enum.to_list()

      assert headers == [
               "Attendee identifier",
               "User email",
               multiple.content,
               second.content,
               "Total"
             ]

      for {_, identity, _, expected_answers, correct} <- cases do
        assert {^correct, 2} = Claper.Quizzes.calculate_user_score(identity, quiz.id)

        row =
          Enum.find(rows, fn [identifier, email | _] ->
            if is_integer(identity),
              do: email == owner.email,
              else: identifier == Base.encode16(identity)
          end)

        assert [_, _, ^expected_answers, "D", total] = row
        assert total == "#{correct}/2"
      end
    end

    test "protects question headers in quiz CSV exports", %{conn: conn} do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      quiz =
        quiz_fixture(%{
          presentation_file: presentation_file,
          quiz_questions: [
            %{
              content: "=SUM(1,2)",
              type: "qcm",
              quiz_question_opts: [%{content: "answer", is_correct: true}]
            }
          ]
        })

      conn =
        conn
        |> log_in_user(owner)
        |> post(~p"/export/quizzes/#{quiz.id}")

      assert CSV.decode!([response(conn, 200)]) |> Enum.to_list() == [
               ["Attendee identifier", "User email", "'=SUM(1,2)", "Total"]
             ]

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="quiz_#{quiz.id}_results.csv")
             ]
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

    test "protects form headers and responses without changing submitted values", %{
      conn: conn,
      form: original_form,
      event: event
    } do
      form =
        form_fixture(%{
          presentation_file_id: original_form.presentation_file_id,
          position: 1,
          fields: [
            %{name: "=Header", type: "text", required: false},
            %{name: "Notes", type: "text", required: false}
          ]
        })

      {:ok, _submit} =
        Claper.Forms.create_or_update_form_submit(event.uuid, %{
          "attendee_identifier" => "attendee-1",
          "form_id" => form.id,
          "response" => %{
            "=Header" => " \t@SUM(1,2)",
            "Notes" => "\r\nordinary,\"quoted\""
          }
        })

      conn = post(conn, ~p"/export/forms/#{form.id}")

      assert CSV.decode!([response(conn, 200)]) |> Enum.to_list() == [
               ["'=Header", "Notes"],
               ["' \t@SUM(1,2)", "'\r\nordinary,\"quoted\""]
             ]
    end

    test "returns 403 for users who don't own the event", %{form: form} do
      stranger = confirmed_user_fixture()
      conn = build_conn() |> log_in_user(stranger)

      conn = post(conn, ~p"/export/forms/#{form.id}")

      assert response(conn, 403) == "Forbidden"
    end
  end

  describe "POST /export/word_clouds/:word_cloud_id" do
    setup %{conn: conn} do
      owner = confirmed_user_fixture()
      presentation_file = presentation_file_fixture(%{user: owner}, [:event])

      word_cloud =
        word_cloud_fixture(%{
          presentation_file: presentation_file,
          title: "First thoughts",
          max_entries: 2
        })

      %{conn: log_in_user(conn, owner), word_cloud: word_cloud, event: presentation_file.event}
    end

    test "exports one row per submitted word, hidden words marked", %{
      conn: conn,
      word_cloud: word_cloud,
      event: event
    } do
      {:ok, _} = Claper.WordClouds.submit_entry(event.uuid, word_cloud, "attendee-1", "Elixir")
      {:ok, _} = Claper.WordClouds.submit_entry(event.uuid, word_cloud, "attendee-1", "Rude")
      {:ok, _} = Claper.WordClouds.hide_word(event.uuid, word_cloud, "rude")

      conn = post(conn, ~p"/export/word_clouds/#{word_cloud.id}")

      assert response_content_type(conn, :csv)

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="word-cloud-First-thoughts.csv")
             ]

      [header_line, elixir_line, rude_line] =
        conn |> response(200) |> String.split("\r\n", trim: true)

      assert header_line == "Attendee identifier,User email,Word,Hidden,Sent at (UTC)"
      assert elixir_line =~ "#{Base.encode16("attendee-1")},N/A,Elixir,false,"
      assert rude_line =~ "#{Base.encode16("attendee-1")},N/A,Rude,true,"
    end

    test "exports formula words as text including CSV-quoted payloads", %{
      conn: conn,
      word_cloud: word_cloud,
      event: event
    } do
      words = [
        "=1+1",
        "+1",
        "-1",
        "@SUM(1,2)",
        "＝1+1",
        "=HYPERLINK(\"https://example.com\",\"click\")",
        "=1\n+2"
      ]

      words
      |> Enum.with_index()
      |> Enum.each(fn {word, index} ->
        assert {:ok, _} =
                 Claper.WordClouds.submit_entry(
                   event.uuid,
                   word_cloud,
                   "attendee-#{index}",
                   word
                 )
      end)

      conn = post(conn, ~p"/export/word_clouds/#{word_cloud.id}")

      assert [headers | rows] = CSV.decode!([response(conn, 200)]) |> Enum.to_list()
      assert headers == ["Attendee identifier", "User email", "Word", "Hidden", "Sent at (UTC)"]

      assert Enum.map(rows, &Enum.at(&1, 2)) == [
               "'=1+1",
               "'+1",
               "'-1",
               "'@SUM(1,2)",
               "'＝1+1",
               "'=HYPERLINK(\"https://example.com\",\"click\")",
               "'=1\n+2"
             ]

      assert Enum.all?(rows, fn row -> length(row) == 5 and Enum.at(row, 3) == "false" end)
    end

    test "returns 403 for users who don't own the event", %{word_cloud: word_cloud} do
      stranger = confirmed_user_fixture()
      conn = build_conn() |> log_in_user(stranger)

      conn = post(conn, ~p"/export/word_clouds/#{word_cloud.id}")

      assert response(conn, 403) == "Forbidden"
    end
  end
end
