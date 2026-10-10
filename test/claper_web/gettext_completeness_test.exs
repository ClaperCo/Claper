defmodule ClaperWeb.GettextCompletenessTest do
  @moduledoc """
  The word cloud's own strings must reach attendees and presenters in their
  language.

  This checks that every catalogue has a translation, never which words it
  uses, so a translator is free to reword any of them. `en` is left out because
  the English catalogue keeps empty translations throughout and falls back to
  the msgid.
  """

  use ExUnit.Case, async: true

  alias Expo.Message.{Plural, Singular}

  @locales ~w(de es fr hu it lv nl sv)

  @msgids [
    "%{count} participant",
    "Attendees can see the word cloud on their device",
    "Create word cloud",
    "Current word cloud",
    "Edit word cloud",
    "Hidden words",
    "Hide the word cloud from attendees",
    "Hide this word",
    "Let your audience answer in their own words.",
    "New word cloud",
    "No word cloud has been created",
    "No words have been sent",
    "No words yet",
    "Question",
    "Show the word cloud to attendees",
    "Show this word again",
    "Thanks! Your word has been added to the cloud.",
    "This will delete all words submitted and the word cloud itself, are you sure?",
    "Type one word or a short phrase...",
    "Type your own word or phrase",
    "What comes to mind when you hear...",
    "Word Cloud",
    "Word Clouds",
    "Words",
    "Words per attendee",
    "You can send one more word.",
    "You have already sent this word.",
    "You have already sent your word.",
    "Your word could not be added. Please type a word or a short phrase."
  ]

  test "every locale translates the word cloud's strings" do
    untranslated =
      for locale <- @locales,
          messages = catalogue(locale),
          msgid <- @msgids,
          not translated?(Map.get(messages, msgid)),
          do: "#{locale}: #{msgid}"

    assert untranslated == []
  end

  defp catalogue(locale) do
    "priv/gettext/#{locale}/LC_MESSAGES/default.po"
    |> Expo.PO.parse_file!()
    |> Map.fetch!(:messages)
    |> Map.new(&{IO.iodata_to_binary(&1.msgid), &1})
  end

  defp translated?(nil), do: false

  defp translated?(message) do
    not fuzzy?(message) and Enum.all?(translations(message), &(&1 != ""))
  end

  defp translations(%Singular{msgstr: msgstr}), do: [IO.iodata_to_binary(msgstr)]

  defp translations(%Plural{msgstr: msgstr}),
    do: Enum.map(msgstr, fn {_index, text} -> IO.iodata_to_binary(text) end)

  defp fuzzy?(message), do: Expo.Message.has_flag?(message, "fuzzy")
end
