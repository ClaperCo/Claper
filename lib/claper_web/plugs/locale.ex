defmodule ClaperWeb.Plugs.Locale do
  @moduledoc """
    Plug to set the locale based on the Accept-Language header.

    ## Usage

    Add the plug to your pipeline in `router.ex`:

        pipeline :browser do
          ...
          plug ClaperWeb.Plugs.Locale
        end

    ## Configuration

    The plug will use the `:default_locale` configuration value as the default
    locale. If the `:default_locale` is not set, it will default to `:en`.

    ## Accept-Language header

    The plug will parse the `Accept-Language` header and set the locale to the
    first language in the list that is known to the application. If no language
    is known, the locale will not be changed.

    The `Accept-Language` header is a comma-separated list of language tags with
    optional quality values. The quality value is a number between 0 and 1,
    where 1 is the highest quality. The quality value is optional and defaults
    to 1.

    Examples:

        Accept-Language: en-US,en;q=0.8,da;q=0.6

    The above example will set the locale to `:en` if it is known to the
    application. If `:en` is not known, it will set the locale to `:da` if it is
    known to the application. If neither `:en` nor `:da` is known, the locale
    will not be changed.

        Accept-Language: en-US,en;q=0.8

    The above example will set the locale to `:en` if it is known to the
    application. If `:en` is not known, the locale will not be changed.

        Accept-Language: en-US

    The above example will set the locale to `:en` if it is known to the
    application. If `:en` is not known, the locale will not be changed.

    ## Known locales

    The plug will only set the locale if it is known to the application. The
    known locales are determined by the `:gettext` configuration. The
    `:gettext` configuration is set in `config/config.exs`:

        config :claper, ClaperWeb.Gettext,
          default_locale: "en",
          default_domain: "claper",
          available_locales: ~w(en fr)

    The `:available_locales` option is
  """

  import Plug.Conn

  def init(_opts), do: nil

  def call(conn, _opts) do
    known_locales = Gettext.known_locales(ClaperWeb.Gettext)
    user_locale = Map.get(conn.assigns.current_user || %{}, :locale)

    accepted_languages =
      extract_accept_language(conn)
      |> Enum.reject(&(String.length(&1) > 2 && not Enum.member?(known_locales, &1)))

    case accepted_languages do
      [locale | _] ->
        Gettext.put_locale(ClaperWeb.Gettext, user_locale || locale)

        conn
        |> put_session(:locale, user_locale || locale)

      _ ->
        conn
    end
  end

  def extract_accept_language(conn) do
    case Plug.Conn.get_req_header(conn, "accept-language") do
      [value | _] ->
        value
        |> String.split(",")
        |> Enum.map(&parse_language_option/1)
        |> Enum.sort(&(&1.quality > &2.quality))
        |> Enum.map(& &1.tag)
        |> Enum.reject(&is_nil/1)
        |> ensure_language_fallbacks()

      _ ->
        []
    end
  end

  defp parse_language_option(string) do
    captures = Regex.named_captures(~r/^\s?(?<tag>[\w\-]+)(?:;q=(?<quality>[\d\.]+))?$/i, string)

    quality =
      case Float.parse(captures["quality"] || "1.0") do
        {val, _} -> val
        _ -> 1.0
      end

    %{tag: captures["tag"], quality: quality}
  end

  defp ensure_language_fallbacks(tags) do
    Enum.flat_map(tags, &fallback_tags(&1, tags))
  end

  defp fallback_tags(tag, tags) do
    case String.split(tag, "-", parts: 2) do
      [language, _country_variant] ->
        if Enum.member?(tags, language), do: [tag], else: [tag, language]

      [_language] ->
        [tag]
    end
  end
end
