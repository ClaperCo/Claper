defmodule ClaperWeb.SubmissionAuditTest do
  use ClaperWeb.ConnCase

  import Claper.AccountsFixtures
  import Claper.PresentationsFixtures
  import Claper.FormsFixtures
  alias Claper.Audit.Log

  setup do
    user = confirmed_user_fixture()
    file = presentation_file_fixture(%{user: user}, [:event])

    socket = %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        current_user: user,
        event: file.event,
        presentation_file: file,
        security_audit_ip: "192.0.2.20"
      }
    }

    %{user: user, presentation_file: file, socket: socket}
  end

  test "form edits remain accepted while rapid submissions create a safe audit record", %{
    user: user,
    presentation_file: file,
    socket: socket
  } do
    form = form_fixture(%{presentation_file_id: file.id})
    socket = Phoenix.Component.assign(socket, :form, form)

    for n <- 1..25 do
      assert {:noreply, updated} =
               ClaperWeb.EventLive.FormComponent.handle_event(
                 "submit",
                 %{"form_submit" => %{"Name" => "private-answer-#{n}"}},
                 socket
               )

      assert updated.assigns.current_form_submit.response == %{"Name" => "private-answer-#{n}"}
    end

    assert Claper.Repo.aggregate(Claper.Forms.FormSubmit, :count) == 1
    assert [log] = Claper.Repo.all(from l in Log, where: l.user_id == ^user.id)
    assert log.resource_id == form.id
    assert log.metadata["reason"] == "submission_burst"
    assert log.metadata["observed_count"] == 20
    refute Jason.encode!(log.metadata) =~ "private-answer"
  end

  test "repeated invalid embed saves are audited without storing HTML", %{
    user: user,
    socket: socket
  } do
    socket = Phoenix.Component.assign(socket, %{live_action: :new, position: 0})

    payload = %{
      "embed" => %{
        "title" => "private-title",
        "provider" => "custom",
        "content" => "<script>private-content</script>"
      }
    }

    for _ <- 1..4 do
      assert {:noreply, updated} =
               ClaperWeb.EmbedLive.FormComponent.handle_event("save", payload, socket)

      refute updated.assigns.changeset.valid?
    end

    assert Claper.Repo.aggregate(Claper.Embeds.Embed, :count) == 0
    assert [log] = Claper.Repo.all(from l in Log, where: l.user_id == ^user.id)
    assert log.resource_type == "embed"
    assert log.metadata["reason"] == "validation_rejected"
    assert log.metadata["observed_count"] == 3
    refute Jason.encode!(log.metadata) =~ "private"
  end
end
