defmodule Claper.WordCloudsTest do
  use Claper.DataCase

  alias Claper.Events.Event
  alias Claper.WordClouds
  alias Claper.WordClouds.{Entry, WordCloud}

  import Claper.{AccountsFixtures, PresentationsFixtures, WordCloudsFixtures}

  defp open_word_cloud(attrs \\ %{}) do
    presentation_file = presentation_file_fixture(%{}, [:event])

    word_cloud =
      word_cloud_fixture(Map.merge(%{presentation_file: presentation_file}, attrs))

    {word_cloud, presentation_file.event.uuid}
  end

  describe "word clouds" do
    test "list_word_clouds/1 returns the word clouds of a presentation" do
      presentation_file = presentation_file_fixture()
      word_cloud = word_cloud_fixture(%{presentation_file: presentation_file})
      word_cloud_fixture()

      assert [%WordCloud{id: id}] = WordClouds.list_word_clouds(presentation_file.id)
      assert id == word_cloud.id
    end

    test "list_word_clouds_at_position/2 returns only the word clouds on that slide" do
      presentation_file = presentation_file_fixture()
      word_cloud = word_cloud_fixture(%{presentation_file: presentation_file, position: 3})
      word_cloud_fixture(%{presentation_file: presentation_file, position: 1})

      assert [%WordCloud{id: id}] =
               WordClouds.list_word_clouds_at_position(presentation_file.id, 3)

      assert id == word_cloud.id
    end

    test "get_word_cloud_for_event/2 finds a word cloud of the event only" do
      presentation_file = presentation_file_fixture()
      word_cloud = word_cloud_fixture(%{presentation_file: presentation_file})
      other_presentation_file = presentation_file_fixture()

      assert %WordCloud{} =
               WordClouds.get_word_cloud_for_event(word_cloud.id, presentation_file.event_id)

      assert WordClouds.get_word_cloud_for_event(word_cloud.id, other_presentation_file.event_id) ==
               nil

      assert WordClouds.get_word_cloud_for_event(-1, presentation_file.event_id) == nil
    end

    test "get_word_cloud_current_position/2 returns the enabled word cloud of the slide" do
      presentation_file = presentation_file_fixture()
      word_cloud_fixture(%{presentation_file: presentation_file, enabled: false})
      enabled = word_cloud_fixture(%{presentation_file: presentation_file, enabled: true})

      assert WordClouds.get_word_cloud_current_position(presentation_file.id, 0).id == enabled.id
    end

    test "create_word_cloud/1 starts with one word per attendee and results shown" do
      presentation_file = presentation_file_fixture()

      assert {:ok, %WordCloud{} = word_cloud} =
               WordClouds.create_word_cloud(%{
                 title: "What comes to mind?",
                 position: 0,
                 presentation_file_id: presentation_file.id
               })

      assert word_cloud.max_entries == 1
      assert word_cloud.show_results
      refute word_cloud.enabled
      assert word_cloud.hidden_words == []
    end

    test "create_word_cloud/1 requires a title" do
      presentation_file = presentation_file_fixture()

      assert {:error, changeset} =
               WordClouds.create_word_cloud(%{
                 title: nil,
                 presentation_file_id: presentation_file.id
               })

      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_word_cloud/1 allows between one and five words per attendee" do
      presentation_file = presentation_file_fixture()
      attrs = %{title: "Words", position: 0, presentation_file_id: presentation_file.id}

      assert {:ok, _} = WordClouds.create_word_cloud(Map.put(attrs, :max_entries, 5))
      assert {:error, too_many} = WordClouds.create_word_cloud(Map.put(attrs, :max_entries, 6))
      assert {:error, too_few} = WordClouds.create_word_cloud(Map.put(attrs, :max_entries, 0))
      assert %{max_entries: [_]} = errors_on(too_many)
      assert %{max_entries: [_]} = errors_on(too_few)
    end

    test "update_word_cloud/3 changes the settings and tells the event" do
      {word_cloud, event_uuid} = open_word_cloud()
      Event.subscribe(event_uuid)

      assert {:ok, %WordCloud{title: "New title", max_entries: 3}} =
               WordClouds.update_word_cloud(event_uuid, word_cloud, %{
                 title: "New title",
                 max_entries: 3
               })

      assert_received {:word_cloud_updated, %WordCloud{title: "New title"}}
    end

    test "delete_word_cloud/2 removes the word cloud and its entries" do
      {word_cloud, event_uuid} = open_word_cloud()
      entry = word_cloud_entry_fixture(%{word_cloud: word_cloud})

      assert {:ok, %WordCloud{}} = WordClouds.delete_word_cloud(event_uuid, word_cloud)
      assert_raise Ecto.NoResultsError, fn -> WordClouds.get_word_cloud!(word_cloud.id) end
      refute Repo.get(Entry, entry.id)
    end

    test "change_word_cloud/1 returns a changeset" do
      word_cloud = word_cloud_fixture()
      assert %Ecto.Changeset{} = WordClouds.change_word_cloud(word_cloud)
    end

    test "disable_all/2 disables every word cloud on the slide" do
      presentation_file = presentation_file_fixture()
      word_cloud = word_cloud_fixture(%{presentation_file: presentation_file, enabled: true})

      WordClouds.disable_all(presentation_file.id, 0)

      refute WordClouds.get_word_cloud!(word_cloud.id).enabled
    end
  end

  describe "words" do
    test "entries that differ only in case and surrounding whitespace form one word" do
      {word_cloud, event_uuid} = open_word_cloud()

      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "b", "  elixir ")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "c", "ELIXIR")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "d", "Phoenix")

      assert [
               %{key: "elixir", text: "Elixir", count: 3, percentage: 75.0},
               %{key: "phoenix", text: "Phoenix", count: 1, percentage: 25.0}
             ] = WordClouds.list_words(word_cloud)
    end

    test "non-ASCII words are grouped regardless of case" do
      {word_cloud, event_uuid} = open_word_cloud()

      assert {:ok, first} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "ÄRGER")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "b", "ärger")

      assert first.normalized_content == "ärger"
      assert [%{key: "ärger", text: "ÄRGER", count: 2}] = WordClouds.list_words(word_cloud)
    end

    test "a word keeps the text of its earliest submission" do
      {word_cloud, event_uuid} = open_word_cloud()

      WordClouds.submit_entry(event_uuid, word_cloud, "a", "phoenix")
      WordClouds.submit_entry(event_uuid, word_cloud, "b", "Phoenix")

      assert [%{text: "phoenix", count: 2}] = WordClouds.list_words(word_cloud)
    end

    test "words with the same count are sorted by text regardless of case" do
      {word_cloud, event_uuid} = open_word_cloud()

      WordClouds.submit_entry(event_uuid, word_cloud, "a", "Zebra")
      WordClouds.submit_entry(event_uuid, word_cloud, "b", "apple")

      assert ["apple", "Zebra"] = word_cloud |> WordClouds.list_words() |> Enum.map(& &1.text)
    end

    test "a precomposed and a decomposed letter form one word" do
      {word_cloud, event_uuid} = open_word_cloud()

      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "\u00E4rger")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "b", "a\u0308rger")

      assert [%{key: "\u00E4rger", count: 2}] = WordClouds.list_words(word_cloud)
    end

    test "a long entry is cut to 60 characters" do
      {word_cloud, event_uuid} = open_word_cloud()
      long = String.duplicate("a", 80)

      assert {:ok, entry} = WordClouds.submit_entry(event_uuid, word_cloud, "a", long)
      assert String.length(entry.content) == 60
    end

    test "a character carrying more combining marks than a column holds is refused" do
      {word_cloud, event_uuid} = open_word_cloud()
      word = "a" <> String.duplicate("\u0301", 300)

      assert {:error, changeset} = WordClouds.submit_entry(event_uuid, word_cloud, "a", word)
      assert %{content: [_]} = errors_on(changeset)
      assert WordClouds.list_entries(word_cloud.id) == []
    end

    test "an empty cloud has no words" do
      {word_cloud, _event_uuid} = open_word_cloud()
      assert WordClouds.list_words(word_cloud) == []
    end
  end

  describe "submit_entry/4" do
    test "stores the word for an anonymous attendee and tells the event" do
      {word_cloud, event_uuid} = open_word_cloud()
      Event.subscribe(event_uuid)

      assert {:ok, %Entry{} = entry} =
               WordClouds.submit_entry(event_uuid, word_cloud, "attendee", "Elixir")

      assert entry.attendee_identifier == "attendee"
      assert entry.user_id == nil
      assert_received {:word_cloud_entry_added, %WordCloud{id: id}}
      assert id == word_cloud.id
    end

    test "stores the word for a signed-in attendee by user" do
      {word_cloud, event_uuid} = open_word_cloud()
      user = user_fixture()

      assert {:ok, %Entry{} = entry} =
               WordClouds.submit_entry(event_uuid, word_cloud, user.id, "Elixir")

      assert entry.user_id == user.id
      assert entry.attendee_identifier == nil
      assert [%Entry{}] = WordClouds.list_entries_for(word_cloud, user.id)
    end

    test "refuses a blank word" do
      {word_cloud, event_uuid} = open_word_cloud()

      assert {:error, changeset} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "   ")
      assert %{content: ["can't be blank"]} = errors_on(changeset)
    end

    test "refuses a word made only of invisible characters" do
      {word_cloud, event_uuid} = open_word_cloud()

      for word <- [" \u200B\uFEFF ", "\u200E\u200F", "\u00AD\u2061"] do
        assert {:error, changeset} = WordClouds.submit_entry(event_uuid, word_cloud, "a", word)
        assert %{content: ["can't be blank"]} = errors_on(changeset)
      end
    end

    test "refuses the same word twice from one attendee" do
      {word_cloud, event_uuid} = open_word_cloud(%{max_entries: 3})

      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")
      assert {:error, changeset} = WordClouds.submit_entry(event_uuid, word_cloud, "a", " elixir")
      assert %{content: ["has already been taken"]} = errors_on(changeset)

      user = user_fixture()
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, user.id, "Elixir")
      assert {:error, _} = WordClouds.submit_entry(event_uuid, word_cloud, user.id, "ELIXIR")
    end

    test "refuses more words than the cloud allows per attendee" do
      {word_cloud, event_uuid} = open_word_cloud(%{max_entries: 2})

      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "one")
      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "a", "two")

      assert {:error, :limit_reached} =
               WordClouds.submit_entry(event_uuid, word_cloud, "a", "three")

      assert {:ok, _} = WordClouds.submit_entry(event_uuid, word_cloud, "b", "three")
    end

    test "refuses a disabled word cloud" do
      {word_cloud, event_uuid} = open_word_cloud(%{enabled: false})

      assert {:error, :not_an_open_word_cloud} =
               WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")

      assert WordClouds.list_entries(word_cloud.id) == []
    end

    test "refuses a word cloud of another event" do
      {word_cloud, _event_uuid} = open_word_cloud()
      {_other_word_cloud, other_event_uuid} = open_word_cloud()

      assert {:error, :not_an_open_word_cloud} =
               WordClouds.submit_entry(other_event_uuid, word_cloud, "a", "Elixir")

      assert WordClouds.list_entries(word_cloud.id) == []
    end

    test "refuses an id that is not a word cloud" do
      {_word_cloud, event_uuid} = open_word_cloud()

      assert {:error, :not_an_open_word_cloud} =
               WordClouds.submit_entry(event_uuid, %WordCloud{id: -1}, "a", "Elixir")
    end
  end

  describe "hidden words" do
    test "a hidden word leaves the cloud but its entries stay stored" do
      {word_cloud, event_uuid} = open_word_cloud()
      WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")
      WordClouds.submit_entry(event_uuid, word_cloud, "b", "Phoenix")
      Event.subscribe(event_uuid)

      assert {:ok, word_cloud} = WordClouds.hide_word(event_uuid, word_cloud, "elixir")
      assert word_cloud.hidden_words == ["elixir"]
      assert_received {:word_cloud_updated, %WordCloud{hidden_words: ["elixir"]}}

      assert [%{key: "phoenix", percentage: 100.0}] = WordClouds.list_words(word_cloud)
      assert length(WordClouds.list_entries(word_cloud.id)) == 2
    end

    test "hiding a word twice keeps it once" do
      {word_cloud, event_uuid} = open_word_cloud()
      WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")

      WordClouds.hide_word(event_uuid, word_cloud, "elixir")
      assert {:ok, word_cloud} = WordClouds.hide_word(event_uuid, word_cloud, "elixir")
      assert word_cloud.hidden_words == ["elixir"]
    end

    test "a key no entry carries is not kept" do
      {word_cloud, event_uuid} = open_word_cloud()
      WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")

      assert {:ok, word_cloud} = WordClouds.hide_word(event_uuid, word_cloud, "phoenix")

      assert {:ok, word_cloud} =
               WordClouds.hide_word(event_uuid, word_cloud, String.duplicate("x", 300))

      assert word_cloud.hidden_words == []
    end

    test "an unhidden word comes back" do
      {word_cloud, event_uuid} = open_word_cloud()
      WordClouds.submit_entry(event_uuid, word_cloud, "a", "Elixir")
      {:ok, word_cloud} = WordClouds.hide_word(event_uuid, word_cloud, "elixir")

      assert {:ok, word_cloud} = WordClouds.unhide_word(event_uuid, word_cloud, "elixir")
      assert word_cloud.hidden_words == []
      assert [%{key: "elixir"}] = WordClouds.list_words(word_cloud)
    end
  end
end
