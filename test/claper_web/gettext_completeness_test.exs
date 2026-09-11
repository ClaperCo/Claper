defmodule ClaperWeb.GettextCompletenessTest do
  @moduledoc """
  The word cloud's own strings must reach an attendee in their language.

  This checks that every catalogue has *a* translation, never which words it
  uses: a translator is free to reword any of these without breaking the build.
  `en` is left out because the English catalogue carries empty translations
  throughout and falls back to the msgid.
  """

  use ExUnit.Case, async: true

  @locales ~w(de es fr hu it lv nl sv)

  @default_domain [
    "Attendees type their own word or short phrase - no choices to set up, the cloud builds itself from what they submit.",
    "Choice",
    "Choices",
    "Poll type",
    "Thanks! Your word has been added to the cloud.",
    "Type one word or a short phrase...",
    "Type your own word or phrase",
    "Word Cloud",
    "Add at least one choice for this poll.",
    "Your word could not be added. Please type a word or a short phrase."
  ]

  @errors_domain [
    "cannot be changed once this poll has been answered, delete the poll to start over"
  ]

  test "every locale translates the strings the word cloud added" do
    untranslated =
      for locale <- @locales,
          {domain, msgids} <- [{"default", @default_domain}, {"errors", @errors_domain}],
          catalogue = File.read!("priv/gettext/#{locale}/LC_MESSAGES/#{domain}.po"),
          msgid <- msgids,
          String.contains?(catalogue, ~s(msgid "#{msgid}"\nmsgstr ""\n)),
          do: "#{locale}/#{domain}: #{msgid}"

    assert untranslated == []
  end
end
