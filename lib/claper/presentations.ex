defmodule Claper.Presentations do
  @moduledoc """
  The Presentations context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Presentations.PresentationFile

  @doc """
  Gets a single presentation_files.

  Raises `Ecto.NoResultsError` if the Presentation files does not exist.

  ## Examples

      iex> get_presentation_file!(123)
      %PresentationFile{}

      iex> get_presentation_file!(456)
      ** (Ecto.NoResultsError)

  """
  def get_presentation_file!(id, preload \\ []),
    do: Repo.get!(PresentationFile, id) |> Repo.preload(preload)

  def get_presentation_files_by_hash(hash) when is_binary(hash),
    do: Repo.all(from p in PresentationFile, where: p.hash == ^hash)

  def get_presentation_files_by_hash(hash) when is_nil(hash),
    do: []

  @doc """
  Returns a list of JPG slide URLs for a given presentation.

  When a `Claper.Presentations.PresentationFile{}` struct is provided, the
  function builds the list of URLs programmatically from the `hash` and
  `length` fields.

  When an integer or binary `hash` is provided, it queries the database for the
  associated presentation file and builds the list of URLs programmatically
  from that.

  When `nil` is provided or when no presentation file is found for the given
  `hash`, it returns an empty list.
  """
  def get_slide_urls(hash_or_presentation_file)

  def get_slide_urls(nil), do: []

  def get_slide_urls(hash) when is_integer(hash), do: get_slide_urls(to_string(hash))

  def get_slide_urls(hash) when is_binary(hash) do
    case Repo.get_by(PresentationFile, hash: hash) do
      nil ->
        []

      presentation ->
        get_slide_urls(hash, presentation.length)
    end
  end

  def get_slide_urls(%PresentationFile{} = presentation) do
    get_slide_urls(presentation.hash, presentation.length)
  end

  @doc """
  Returns a list of JPG slide URLs for a given presentation `hash` and
  `length`. See also `get_slide_urls/1`.
  """
  def get_slide_urls(hash, length) when is_binary(hash) and is_integer(length) do
    config = Application.get_env(:claper, :presentations)

    case Keyword.fetch!(config, :storage) do
      "local" ->
        for index <- 1..length do
          "/uploads/#{hash}/#{index}.jpg"
        end

      "s3" ->
        base_url = Keyword.fetch!(config, :s3_public_url)

        for index <- 1..length do
          base_url <> "/presentations/#{hash}/#{index}.jpg"
        end

      storage ->
        raise "Unrecognised presentations storage value #{storage}"
    end
  end

  @doc """
  Creates a presentation_files.

  ## Examples

      iex> create_presentation_file(%{field: value})
      {:ok, %PresentationFile{}}

      iex> create_presentation_file(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_presentation_file(attrs \\ %{}) do
    %PresentationFile{}
    |> PresentationFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a presentation_files.

  ## Examples

      iex> update_presentation_file(presentation_file, %{field: new_value})
      {:ok, %PresentationFile{}}

      iex> update_presentation_file(presentation_file, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_presentation_file(%PresentationFile{} = presentation_file, attrs) do
    presentation_file
    |> PresentationFile.changeset(attrs)
    |> Repo.update()
  end

  def subscribe(presentation_file_id) do
    Phoenix.PubSub.subscribe(Claper.PubSub, "presentation:#{presentation_file_id}")
  end

  alias Claper.Presentations.PresentationState

  @doc """
  Creates a presentation_state.

  ## Examples

      iex> create_presentation_state(%{field: value})
      {:ok, %PresentationState{}}

      iex> create_presentation_state(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_presentation_state(attrs \\ %{}) do
    %PresentationState{}
    |> PresentationState.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a presentation_state.

  ## Examples

      iex> update_presentation_state(presentation_state, %{field: new_value})
      {:ok, %PresentationState{}}

      iex> update_presentation_state(presentation_state, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_presentation_state(%PresentationState{} = presentation_state, attrs) do
    presentation_state
    |> PresentationState.changeset(attrs)
    |> Repo.update()
    |> broadcast(:state_updated)
  end

  defp broadcast({:error, _reason} = error, _state), do: error

  defp broadcast({:ok, state}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "presentation:#{state.presentation_file_id}",
      {event, state}
    )

    {:ok, state}
  end
end
