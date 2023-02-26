defmodule Claper.Forms do
  @moduledoc """
  The Forms context.
  """

  import Ecto.Query, warn: false
  alias Claper.Repo

  alias Claper.Forms.Form
  alias Claper.Forms.FormSubmit
  alias Claper.Forms.Field

  @doc """
  Returns the list of forms for a given presentation file.

  ## Examples

      iex> list_forms(123)
      [%Form{}, ...]

  """
  def list_forms(presentation_file_id) do
    from(f in Form,
      where: f.presentation_file_id == ^presentation_file_id,
      order_by: [asc: f.id, asc: f.position]
    )
    |> Repo.all()
  end

  @doc """
  Returns the list of forms for a given presentation file and a given position.

  ## Examples

      iex> list_forms_at_position(123, 0)
      [%Form{}, ...]

  """
  def list_forms_at_position(presentation_file_id, position) do
    from(f in Form,
      where: f.presentation_file_id == ^presentation_file_id and f.position == ^position,
      order_by: [asc: f.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single form.

  Raises `Ecto.NoResultsError` if the Form does not exist.

  ## Examples

      iex> get_form!(123)
      %Poll{}

      iex> get_form!(456)
      ** (Ecto.NoResultsError)

  """
  def get_form!(id, preload \\ []),
    do:
      Repo.get!(Form, id) |> Repo.preload(preload)

  @doc """
  Gets a single form for a given position.

  ## Examples

      iex> get_form!(123, 0)
      %Form{}

  """
  def get_form_current_position(presentation_file_id, position) do
    from(f in Form,
      where:
        f.position == ^position and f.presentation_file_id == ^presentation_file_id and
          f.enabled == true
    )
    |> Repo.one()
  end

  @doc """
  Creates a form.

  ## Examples

      iex> create_form(%{field: value})
      {:ok, %Form{}}

      iex> create_form(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form(attrs \\ %{}) do
    %Form{}
    |> Form.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a form.

  ## Examples

      iex> update_form("123e4567-e89b-12d3-a456-426614174000", form, %{field: new_value})
      {:ok, %Form{}}

      iex> update_form("123e4567-e89b-12d3-a456-426614174000", form, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_form(event_uuid, %Form{} = form, attrs) do
    form
    |> Form.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, form} ->
        broadcast({:ok, form, event_uuid}, :form_updated)

      {:error, changeset} ->
        {:error, %{changeset | action: :update}}
    end
  end

  @doc """
  Deletes a form.

  ## Examples

      iex> delete_form("123e4567-e89b-12d3-a456-426614174000", form)
      {:ok, %Form{}}

      iex> delete_form("123e4567-e89b-12d3-a456-426614174000", form)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form(event_uuid, %Form{} = form) do
    {:ok, form} = Repo.delete(form)
    broadcast({:ok, form, event_uuid}, :form_deleted)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form changes.

  ## Examples

      iex> change_form(form)
      %Ecto.Changeset{data: %Form{}}

  """
  def change_form(%Form{} = form, attrs \\ %{}) do
    Form.changeset(form, attrs)
  end

  @doc """
  Add an empty form field to a form changeset.
  """
  def add_form_field(changeset) do
    changeset
    |> Ecto.Changeset.put_embed(
      :fields,
      Ecto.Changeset.get_field(changeset, :fields) ++ [%Field{}]
    )
  end

  @doc """
  Remove a form field from a form changeset.
  """
  def remove_form_field(changeset, field) do
    changeset
    |> Ecto.Changeset.put_embed(
      :fields,
      Ecto.Changeset.get_field(changeset, :fields) -- [field]
    )
  end

  def disable_all(presentation_file_id, position) do
    from(f in Form,
      where:
        f.presentation_file_id == ^presentation_file_id and f.position == ^position
    )
    |> Repo.update_all(set: [enabled: false])
  end

  def set_default(id, presentation_file_id, position) do
    from(f in Form,
      where:
        f.presentation_file_id == ^presentation_file_id and f.position == ^position and
          f.id != ^id
    )
    |> Repo.update_all(set: [enabled: false])

    from(f in Form,
      where:
        f.presentation_file_id == ^presentation_file_id and f.position == ^position and
          f.id == ^id
    )
    |> Repo.update_all(set: [enabled: true])
  end

  defp broadcast({:error, _reason} = error, _form), do: error

  defp broadcast({:ok, form, event_uuid}, event) do
    Phoenix.PubSub.broadcast(
      Claper.PubSub,
      "event:#{event_uuid}",
      {event, form}
    )

    {:ok, form}
  end

  @doc """
  Creates a form submit.

  ## Examples

      iex> create_form_submit(%{field: value})
      {:ok, %FormSubmit{}}

      iex> create_form_submit(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_form_submit(attrs \\ %{}) do
    %FormSubmit{}
    |> FormSubmit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the list of form submissions for a given presentation file.

  ## Examples

      iex> list_form_submits(123)
      [%FormSubmit{}, ...]

  """
  def list_form_submits(presentation_file_id) do
    from(fs in FormSubmit,
      join: f in Form, on: f.id == fs.form_id,
      where: f.presentation_file_id == ^presentation_file_id
    )
    |> Repo.all()
  end

  @doc """
  Gets a single FormSubmit.

  ## Examples

      iex> get_form_submit!(321, 123)
      %FormSubmit{}

  """
  def get_form_submit(user_id, form_id) when is_number(user_id),
    do: Repo.get_by(FormSubmit, form_id: form_id, user_id: user_id)
  def get_form_submit(attendee_identifier, form_id),
    do: Repo.get_by(FormSubmit, form_id: form_id, attendee_identifier: attendee_identifier)

  @doc """
  Gets a single FormSubmit by its ID.

  Raises `Ecto.NoResultsError` if the FormSubmit does not exist.

  ## Examples

      iex> get_form_submit_by_id!("123e4567-e89b-12d3-a456-426614174000")
      %Post{}

      iex> get_form_submit_by_id!("123e4567-e89b-12d3-a456-426614174123")
      ** (Ecto.NoResultsError)

  """
  def get_form_submit_by_id!(id, preload \\ []), do: Repo.get_by!(FormSubmit, id: id) |> Repo.preload(preload)

  @doc """
  Creates or update a FormSubmit.

  ## Examples

      iex> create_or_update_form_submit(%{field: value})
      {:ok, %FormSubmit{}}

      iex> create_or_update_form_submit(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_or_update_form_submit(event_uuid, %{"user_id" => user_id, "form_id" => form_id} = attrs) when is_number(user_id) do
    get_form_submit(user_id, form_id) |> create_or_update_form_submit(event_uuid, attrs)
  end

  def create_or_update_form_submit(event_uuid, %{"attendee_identifier" => attendee_identifier, "form_id" => form_id} = attrs) do
    get_form_submit(attendee_identifier, form_id) |> create_or_update_form_submit(event_uuid, attrs)

  end

  def create_or_update_form_submit(fs, event_uuid, attrs) do
    case fs do
      nil  -> %FormSubmit{}
      form_submit -> form_submit
    end
    |> FormSubmit.changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, r} -> case fs do
        nil  -> broadcast({:ok, r, event_uuid}, :form_submit_created)
        _form_submit -> broadcast({:ok, r, event_uuid}, :form_submit_updated)
      end
    end
  end

  @doc """
  Deletes a form submit.

  ## Examples

      iex> delete_form_submit(post, event_id)
      {:ok, %FormSubmit{}}

      iex> delete_form_submit(post, event_id)
      {:error, %Ecto.Changeset{}}

  """
  def delete_form_submit(event_uuid, %FormSubmit{} = fs) do
    fs
    |> Repo.delete()
    |> case do
      {:ok, r} -> broadcast({:ok, r, event_uuid}, :form_submit_deleted)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking form submit changes.

  ## Examples

      iex> change_form_submit(form_submit)
      %Ecto.Changeset{data: %FormSubmit{}}

  """
  def change_form_submit(%FormSubmit{} = form_submit, attrs \\ %{}) do
    FormSubmit.changeset(form_submit, attrs)
  end
end
