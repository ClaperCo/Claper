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
