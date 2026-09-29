defmodule Claper.ScalesTest do
  use Claper.DataCase

  alias Claper.Events.Event
  alias Claper.Scales
  alias Claper.Scales.{Scale, ScaleResponse}

  import Claper.{AccountsFixtures, PresentationsFixtures, ScalesFixtures}

  defp open_scale(attrs \\ %{}) do
    presentation_file = presentation_file_fixture(%{}, [:event])
    scale = scale_fixture(Map.merge(%{presentation_file: presentation_file}, attrs))

    {scale, presentation_file.event.uuid}
  end

  defp scale_changeset(attrs) do
    Scale.changeset(
      %Scale{},
      Map.merge(%{title: "Mood", position: 0, presentation_file_id: 1}, attrs)
    )
  end

  defp response_changeset(scale, attrs) do
    ScaleResponse.changeset(
      %ScaleResponse{},
      Map.merge(%{attendee_identifier: "a"}, attrs),
      scale
    )
  end

  describe "scale changeset" do
    test "accepts a range from 1 to 10 in steps of 1 by default" do
      changeset = scale_changeset(%{})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :min_value) == 1
      assert Ecto.Changeset.get_field(changeset, :max_value) == 10
      assert Ecto.Changeset.get_field(changeset, :step) == 1
    end

    test "requires a title" do
      assert %{title: ["can't be blank"]} = errors_on(scale_changeset(%{title: nil}))
    end

    test "requires the highest value to be above the lowest" do
      assert %{max_value: [_]} = errors_on(scale_changeset(%{min_value: 5, max_value: 5}))
      assert %{max_value: [_]} = errors_on(scale_changeset(%{min_value: 5, max_value: 2}))
    end

    test "requires a positive step" do
      assert %{step: [_]} = errors_on(scale_changeset(%{step: 0}))
      assert %{step: [_]} = errors_on(scale_changeset(%{step: -1}))
    end

    test "requires the step to reach the highest value" do
      assert %{step: [_]} = errors_on(scale_changeset(%{min_value: 0, max_value: 10, step: 3}))
      assert scale_changeset(%{min_value: 0, max_value: 10, step: 5}).valid?
    end

    test "allows at most 101 points" do
      assert scale_changeset(%{min_value: 0, max_value: 100}).valid?
      assert %{step: [_]} = errors_on(scale_changeset(%{min_value: 0, max_value: 101}))
      assert scale_changeset(%{min_value: -500, max_value: 500, step: 10}).valid?
    end

    test "accepts negative values" do
      assert scale_changeset(%{min_value: -5, max_value: 5}).valid?
    end

    test "keeps values within the size of an integer column" do
      assert %{min_value: [_]} =
               errors_on(scale_changeset(%{min_value: -10_000_000_000, max_value: 1}))
    end

    test "refuses a value that is not an integer" do
      assert %{min_value: ["is invalid"]} = errors_on(scale_changeset(%{min_value: "1.5"}))
    end

    test "limits the labels to 60 characters" do
      label = String.duplicate("a", 61)

      assert %{min_label: [_], max_label: [_]} =
               errors_on(scale_changeset(%{min_label: label, max_label: label}))
    end

    test "locks the range once the scale has been answered" do
      scale = %Scale{title: "Mood", position: 0, presentation_file_id: 1}

      for {field, value} <- [min_value: 0, max_value: 9, step: 3] do
        changeset = Scale.changeset(scale, %{field => value}, answered: true)

        assert %{^field => ["cannot be changed once attendees have answered"]} =
                 errors_on(changeset)
      end

      assert Scale.changeset(scale, %{title: "New", min_label: "Low"}, answered: true).valid?
      assert Scale.changeset(scale, %{min_value: 1, max_value: "10"}, answered: true).valid?
    end
  end

  describe "points/1 and middle/1" do
    test "list every value an attendee can pick" do
      assert Scale.points(%Scale{min_value: 0, max_value: 10, step: 5}) == [0, 5, 10]
      assert Scale.points(%Scale{min_value: -2, max_value: 2, step: 1}) == [-2, -1, 0, 1, 2]
    end

    test "start the slider on the middle point, or the lower of the two" do
      assert Scale.middle(%Scale{min_value: 0, max_value: 10, step: 1}) == 5
      assert Scale.middle(%Scale{min_value: 1, max_value: 10, step: 1}) == 5
      assert Scale.middle(%Scale{min_value: 0, max_value: 10, step: 5}) == 5
      assert Scale.middle(%Scale{min_value: 0, max_value: 15, step: 5}) == 5
    end
  end

  describe "response changeset" do
    setup do
      %{scale: %Scale{id: 1, min_value: 0, max_value: 10, step: 2}}
    end

    test "accepts a point of the scale, including both ends", %{scale: scale} do
      for value <- [0, 4, 10, "6"] do
        assert response_changeset(scale, %{value: value}).valid?
      end
    end

    test "refuses a value outside the range", %{scale: scale} do
      assert %{value: [_]} = errors_on(response_changeset(scale, %{value: -2}))
      assert %{value: [_]} = errors_on(response_changeset(scale, %{value: 12}))
    end

    test "refuses a value between two points", %{scale: scale} do
      assert %{value: ["is not a point on the scale"]} =
               errors_on(response_changeset(scale, %{value: 3}))
    end

    test "refuses a value that is not an integer", %{scale: scale} do
      for value <- ["4.0", "four", "", nil, %{"a" => 1}] do
        refute response_changeset(scale, %{value: value}).valid?
      end
    end

    test "needs exactly one respondent", %{scale: scale} do
      assert %{user_id: [_]} =
               errors_on(
                 ScaleResponse.changeset(
                   %ScaleResponse{},
                   %{value: 2, attendee_identifier: nil},
                   scale
                 )
               )

      assert %{user_id: [_]} =
               errors_on(response_changeset(scale, %{value: 2, user_id: 5}))
    end

    test "takes the scale from the scale passed in, not from the params", %{scale: scale} do
      changeset = response_changeset(scale, %{value: 2, scale_id: 99})
      assert Ecto.Changeset.get_field(changeset, :scale_id) == 1
    end
  end

  describe "scales" do
    test "list_scales/1 returns the scales of a presentation" do
      presentation_file = presentation_file_fixture()
      scale = scale_fixture(%{presentation_file: presentation_file})
      scale_fixture()

      assert [%Scale{id: id}] = Scales.list_scales(presentation_file.id)
      assert id == scale.id
    end

    test "list_scales_at_position/2 returns only the scales on that slide" do
      presentation_file = presentation_file_fixture()
      scale = scale_fixture(%{presentation_file: presentation_file, position: 3})
      scale_fixture(%{presentation_file: presentation_file, position: 1})

      assert [%Scale{id: id}] = Scales.list_scales_at_position(presentation_file.id, 3)
      assert id == scale.id
    end

    test "get_scale_for_event/2 finds a scale of the event only" do
      presentation_file = presentation_file_fixture()
      scale = scale_fixture(%{presentation_file: presentation_file})
      other_presentation_file = presentation_file_fixture()

      assert %Scale{} = Scales.get_scale_for_event(scale.id, presentation_file.event_id)
      assert Scales.get_scale_for_event(scale.id, other_presentation_file.event_id) == nil
      assert Scales.get_scale_for_event(-1, presentation_file.event_id) == nil
    end

    test "get_scale_current_position/2 returns the enabled scale of the slide" do
      presentation_file = presentation_file_fixture()
      scale_fixture(%{presentation_file: presentation_file, enabled: false})
      enabled = scale_fixture(%{presentation_file: presentation_file, enabled: true})

      assert Scales.get_scale_current_position(presentation_file.id, 0).id == enabled.id
    end

    test "create_scale/1 starts closed with results shown" do
      presentation_file = presentation_file_fixture()

      assert {:ok, %Scale{} = scale} =
               Scales.create_scale(%{
                 title: "How confident are you?",
                 position: 0,
                 presentation_file_id: presentation_file.id
               })

      assert {scale.min_value, scale.max_value, scale.step} == {1, 10, 1}
      assert scale.show_results
      refute scale.enabled
    end

    test "create_scale/1 refuses an invalid range" do
      presentation_file = presentation_file_fixture()

      assert {:error, changeset} =
               Scales.create_scale(%{
                 title: "Mood",
                 min_value: 10,
                 max_value: 1,
                 position: 0,
                 presentation_file_id: presentation_file.id
               })

      assert %{max_value: [_]} = errors_on(changeset)
    end

    test "update_scale/3 changes the settings and tells the event" do
      {scale, event_uuid} = open_scale()
      Event.subscribe(event_uuid)

      assert {:ok, %Scale{title: "New title", min_value: 0, max_value: 5}} =
               Scales.update_scale(event_uuid, scale, %{
                 title: "New title",
                 min_value: 0,
                 max_value: 5
               })

      assert_received {:scale_updated, %Scale{title: "New title"}}
    end

    test "delete_scale/2 removes the scale and its responses" do
      {scale, event_uuid} = open_scale()
      response = scale_response_fixture(%{scale: scale})

      assert {:ok, %Scale{}} = Scales.delete_scale(event_uuid, scale)
      assert_raise Ecto.NoResultsError, fn -> Scales.get_scale!(scale.id) end
      refute Repo.get(ScaleResponse, response.id)
    end

    test "disable_all/2 disables every scale on the slide" do
      presentation_file = presentation_file_fixture()
      scale = scale_fixture(%{presentation_file: presentation_file, enabled: true})

      Scales.disable_all(presentation_file.id, 0)

      refute Scales.get_scale!(scale.id).enabled
    end
  end

  describe "editing the range after responses" do
    test "the range can change freely while nobody has answered" do
      {scale, event_uuid} = open_scale()
      refute Scales.answered?(scale)

      assert {:ok, %Scale{min_value: 0, max_value: 100, step: 5}} =
               Scales.update_scale(event_uuid, scale, %{min_value: 0, max_value: 100, step: 5})
    end

    test "the range is refused once someone has answered, the rest still changes" do
      {scale, event_uuid} = open_scale()
      {:ok, _} = Scales.submit_response(event_uuid, scale, "a", "7")
      assert Scales.answered?(scale)

      assert {:error, changeset} = Scales.update_scale(event_uuid, scale, %{max_value: 5})

      assert %{max_value: ["cannot be changed once attendees have answered"]} =
               errors_on(changeset)

      assert {:error, _} = Scales.update_scale(event_uuid, scale, %{min_value: 0})
      assert {:error, _} = Scales.update_scale(event_uuid, scale, %{step: 3, max_value: 7})

      assert {:ok, updated} =
               Scales.update_scale(event_uuid, scale, %{
                 title: "Renamed",
                 min_label: "Low",
                 max_label: "High",
                 min_value: "1",
                 max_value: "10"
               })

      assert {updated.title, updated.min_label, updated.max_label} == {"Renamed", "Low", "High"}
      assert {updated.min_value, updated.max_value, updated.step} == {1, 10, 1}
    end

    test "the rule is checked against the stored scale, not a stale struct" do
      {scale, event_uuid} = open_scale()
      {:ok, _} = Scales.submit_response(event_uuid, scale, "a", "7")

      stale = %{scale | min_value: 0}

      assert {:error, changeset} = Scales.update_scale(event_uuid, stale, %{min_value: 0})
      assert %{min_value: [_]} = errors_on(changeset)
      assert Scales.get_scale!(scale.id).min_value == 1
    end
  end

  describe "submit_response/4" do
    test "stores the value for an anonymous attendee and tells the event" do
      {scale, event_uuid} = open_scale()
      Event.subscribe(event_uuid)

      assert {:ok, %ScaleResponse{} = response} =
               Scales.submit_response(event_uuid, scale, "attendee", "7")

      assert response.value == 7
      assert response.attendee_identifier == "attendee"
      assert response.user_id == nil
      assert_received {:scale_response_added, %Scale{id: id}}
      assert id == scale.id
      assert Scales.get_response_for(scale, "attendee").id == response.id
    end

    test "stores the value for a signed-in attendee by user" do
      {scale, event_uuid} = open_scale()
      user = user_fixture()

      assert {:ok, %ScaleResponse{} = response} =
               Scales.submit_response(event_uuid, scale, user.id, 3)

      assert response.user_id == user.id
      assert response.attendee_identifier == nil
      assert Scales.get_response_for(scale, user.id).id == response.id
    end

    test "takes one response per anonymous attendee" do
      {scale, event_uuid} = open_scale()

      assert {:ok, _} = Scales.submit_response(event_uuid, scale, "a", "7")
      assert {:error, changeset} = Scales.submit_response(event_uuid, scale, "a", "2")
      assert %{scale_id: ["has already been taken"]} = errors_on(changeset)
      assert {:ok, _} = Scales.submit_response(event_uuid, scale, "b", "2")

      assert [%{value: 7}, %{value: 2}] = Scales.list_responses(scale.id)
    end

    test "takes one response per signed-in attendee" do
      {scale, event_uuid} = open_scale()
      user = user_fixture()

      assert {:ok, _} = Scales.submit_response(event_uuid, scale, user.id, "7")
      assert {:error, changeset} = Scales.submit_response(event_uuid, scale, user.id, "2")
      assert %{scale_id: ["has already been taken"]} = errors_on(changeset)
      assert [%{value: 7}] = Scales.list_responses(scale.id)
    end

    test "the database keeps one response per respondent even without the changeset" do
      {scale, _event_uuid} = open_scale()
      user = user_fixture()
      insert = &Repo.insert(struct(ScaleResponse, Map.put(&1, :scale_id, scale.id)))

      assert {:ok, _} = insert.(%{value: 1, attendee_identifier: "a"})
      assert_raise Ecto.ConstraintError, fn -> insert.(%{value: 2, attendee_identifier: "a"}) end
      assert {:ok, _} = insert.(%{value: 1, user_id: user.id})
      assert_raise Ecto.ConstraintError, fn -> insert.(%{value: 2, user_id: user.id}) end
    end

    test "the database refuses a response with no respondent or with two" do
      {scale, _event_uuid} = open_scale()
      user = user_fixture()
      insert = &Repo.insert(struct(ScaleResponse, Map.put(&1, :scale_id, scale.id)))

      assert_raise Ecto.ConstraintError, fn -> insert.(%{value: 1}) end

      assert_raise Ecto.ConstraintError, fn ->
        insert.(%{value: 1, user_id: user.id, attendee_identifier: "a"})
      end
    end

    test "refuses a value outside the range or between two points" do
      {scale, event_uuid} = open_scale(%{min_value: 0, max_value: 10, step: 5})

      for value <- ["-5", "15", "3", "abc", "5.0"] do
        assert {:error, %Ecto.Changeset{}} = Scales.submit_response(event_uuid, scale, "a", value)
      end

      assert Scales.list_responses(scale.id) == []
      assert {:ok, _} = Scales.submit_response(event_uuid, scale, "a", "10")
    end

    test "checks the value against the stored range, not the struct passed in" do
      {scale, event_uuid} = open_scale(%{min_value: 1, max_value: 5})
      widened = %{scale | max_value: 100}

      assert {:error, changeset} = Scales.submit_response(event_uuid, widened, "a", "50")
      assert %{value: [_]} = errors_on(changeset)
    end

    test "refuses a disabled scale" do
      {scale, event_uuid} = open_scale(%{enabled: false})

      assert {:error, :not_an_open_scale} = Scales.submit_response(event_uuid, scale, "a", "5")
      assert Scales.list_responses(scale.id) == []
    end

    test "refuses a scale of another event" do
      {scale, _event_uuid} = open_scale()
      {_other_scale, other_event_uuid} = open_scale()

      assert {:error, :not_an_open_scale} =
               Scales.submit_response(other_event_uuid, scale, "a", "5")

      assert Scales.list_responses(scale.id) == []
    end

    test "refuses an id that is not a scale" do
      {_scale, event_uuid} = open_scale()

      assert {:error, :not_an_open_scale} =
               Scales.submit_response(event_uuid, %Scale{id: -1}, "a", "5")
    end
  end

  describe "results/1" do
    test "an unanswered scale has no average or median and an empty distribution" do
      {scale, _event_uuid} = open_scale(%{min_value: 1, max_value: 3})

      assert %{
               count: 0,
               average: nil,
               median: nil,
               distribution: [
                 %{value: 1, count: 0, percentage: +0.0, weight: +0.0},
                 %{value: 2, count: 0, percentage: +0.0, weight: +0.0},
                 %{value: 3, count: 0, percentage: +0.0, weight: +0.0}
               ]
             } = Scales.results(scale)
    end

    test "counts, averages and spreads the responses over every point" do
      {scale, event_uuid} = open_scale(%{min_value: 0, max_value: 10, step: 5})

      for {identity, value} <- [{"a", 0}, {"b", 10}, {"c", 10}, {"d", 5}] do
        {:ok, _} = Scales.submit_response(event_uuid, scale, identity, value)
      end

      assert %{count: 4, average: 6.25, median: 7.5, distribution: distribution} =
               Scales.results(scale)

      assert [
               %{value: 0, count: 1, percentage: 25.0, weight: 50.0},
               %{value: 5, count: 1, percentage: 25.0, weight: 50.0},
               %{value: 10, count: 2, percentage: 50.0, weight: 100.0}
             ] = distribution
    end

    test "the median of an odd count is the middle response" do
      {scale, event_uuid} = open_scale()

      for {identity, value} <- [{"a", 1}, {"b", 9}, {"c", 4}] do
        {:ok, _} = Scales.submit_response(event_uuid, scale, identity, value)
      end

      assert %{count: 3, median: 4.0} = Scales.results(scale)
    end

    test "only counts the responses to that scale" do
      {scale, event_uuid} = open_scale()
      {other, other_event_uuid} = open_scale()
      {:ok, _} = Scales.submit_response(event_uuid, scale, "a", 2)
      {:ok, _} = Scales.submit_response(other_event_uuid, other, "a", 9)

      assert %{count: 1, average: 2.0} = Scales.results(scale)
    end
  end
end
