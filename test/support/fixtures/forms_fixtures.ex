defmodule Claper.FormsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Claper.Forms` context.
  """

  import Claper.{AccountsFixtures, PresentationsFixtures}

  require Claper.UtilFixture

  @doc """
  Generate a form.
  """
  def form_fixture(attrs \\ %{}, preload \\ []) do
    {:ok, form} =
      attrs
      |> Enum.into(%{
        title: "some title",
        position: 0,
        enabled: true,
        fields: [%{name: "Name", type: "text"}]
      })
      |> Claper.Forms.create_form()

    Claper.UtilFixture.merge_preload(form, preload, %{})
  end

  @doc """
  Generate a form submit.
  """
  def form_submit_fixture(attrs \\ %{}) do
    presentation_file = presentation_file_fixture()
    form = form_fixture(%{presentation_file_id: presentation_file.id})
    assoc = %{form: form}

    {:ok, form_submit} =
      attrs
      |> Enum.into(%{
        form_id: assoc.form.id,
        user_id: user_fixture().id,
        response: %{"Test" => "some option 1", "Test2" => "some option 2"}
      })
      |> Claper.Forms.create_form_submit()

    form_submit
  end
end
