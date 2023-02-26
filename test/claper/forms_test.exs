defmodule Claper.FormsTest do
  use Claper.DataCase

  alias Claper.Forms

  describe "forms" do
    alias Claper.Forms.Form

    import Claper.{FormsFixtures, PresentationsFixtures}

    @invalid_attrs %{title: nil}

    test "list_forms/1 returns all forms from a presentation" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id})

      assert Forms.list_forms(presentation_file.id) == [form]
    end

    test "list_forms_at_position/2 returns all forms from a presentation at a given position" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id, position: 5})

      assert Forms.list_forms_at_position(presentation_file.id, 5) == [form]
    end

    test "get_form!/1 returns the form with given id" do
      presentation_file = presentation_file_fixture()

      form =
        form_fixture(%{presentation_file_id: presentation_file.id})\

      assert Forms.get_form!(form.id) == form
    end

    test "create_form/1 with valid data creates a form" do
      presentation_file = presentation_file_fixture()

      valid_attrs = %{
        title: "some title",
        presentation_file_id: presentation_file.id,
        position: 0,
        fields: [
          %{name: "some option 1", type: "text"},
          %{name: "some option 2", type: "email"}
        ]
      }

      assert {:ok, %Form{} = form} = Forms.create_form(valid_attrs)
      assert form.title == "some title"
    end

    test "create_form/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Forms.create_form(@invalid_attrs)
    end

    test "update_form/3 with valid data updates the form" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id})
      update_attrs = %{title: "some updated title"}

      assert {:ok, %Form{} = form} =
               Forms.update_form(presentation_file.event_id, form, update_attrs)

      assert form.title == "some updated title"
    end

    test "update_form/3 with invalid data returns error changeset" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id})

      assert {:error, %Ecto.Changeset{}} =
               Forms.update_form(presentation_file.event_id, form, @invalid_attrs)

      assert form == Forms.get_form!(form.id)
    end

    test "delete_form/2 deletes the form" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id})

      assert {:ok, %Form{}} = Forms.delete_form(presentation_file.event_id, form)
      assert_raise Ecto.NoResultsError, fn -> Forms.get_form!(form.id) end
    end

    test "change_form/1 returns a form changeset" do
      presentation_file = presentation_file_fixture()
      form = form_fixture(%{presentation_file_id: presentation_file.id})
      assert %Ecto.Changeset{} = Forms.change_form(form)
    end

  end

  describe "form_submits" do
    import Claper.{FormsFixtures, PresentationsFixtures}

    test "get_form_submit/2 returns the form_submit with given id and user id" do
      form_submit = form_submit_fixture()
      assert Forms.get_form_submit(form_submit.user_id, form_submit.form_id) == form_submit
    end

    test "create_or_update_form_submit/3 with valid data edit a form_submit" do
      presentation_file = presentation_file_fixture(%{}, [:event])
      f = form_fixture(%{presentation_file_id: presentation_file.id})


      assert {:ok, %Claper.Forms.FormSubmit{}} =
               Forms.create_or_update_form_submit(
                presentation_file.event_id,
                %{
                  "user_id" => presentation_file.event.user_id,
                  "form_id" => f.id,
                  "response" => %{:"Test" => "some option 1", :"Test 2" => "some option 2"}
                }
               )
    end
  end

end
