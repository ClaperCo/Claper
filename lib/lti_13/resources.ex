defmodule Lti13.Resources do
  import Ecto.Query, warn: false
  alias Claper.Repo
  alias Lti13.Resources.Resource

  def create_resource(attrs) do
    %Resource{}
    |> Resource.changeset(attrs)
    |> Repo.insert()
  end

  def get_resource_by_id_and_registration(resource_id, registration_id) do
    from(r in Resource,
      where: r.resource_id == ^resource_id and r.registration_id == ^registration_id
    )
    |> Repo.one()
    |> case do
      nil -> nil
      resource -> resource |> Repo.preload(:event)
    end
  end

  @doc """
  Creates a resource and event with the given title and resource_id

  ## Examples
      iex> create_resource_with_event(%{title: "Test", resource_id: "123", line_items_url: "https://example.com", lti_user: %Lti13.Users.User{}})
      {:ok, %Claper.Events.Event{}, %Lti13.Resources.Resource{}}
      iex> create_resource_with_event(%{})
      {:error, %{reason: :invalid_resource, msg: "Failed to create resource"}}
  """
  def create_resource_with_event(%{
        title: title,
        resource_id: resource_id,
        line_items_url: line_items_url,
        lti_user: lti_user
      }) do
    with {:ok, event} <-
           Claper.Events.create_event(%{
             name: title,
             code:
               :crypto.strong_rand_bytes(10) |> Base.encode16(case: :lower) |> binary_part(0, 6),
             user_id: lti_user.user_id,
             started_at: NaiveDateTime.utc_now(),
             presentation_file: %{
               "status" => "done",
               "length" => 0,
               "presentation_state" => %{}
             }
           }),
         {:ok, resource} <-
           create_resource(%{
             title: title,
             resource_id: resource_id,
             line_items_url: line_items_url,
             event_id: event.id,
             registration_id: lti_user.registration_id
           }) do
      {:ok, resource |> Map.put(:event, event)}
    else
      {:error, _} -> {:error, %{reason: :invalid_resource, msg: "Failed to create resource"}}
    end
  end
end
