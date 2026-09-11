defmodule Claper.Polls.PollOpt do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          content: String.t(),
          vote_count: integer(),
          rating_value: integer() | nil,
          percentage: float(),
          poll_id: integer(),
          poll: Claper.Polls.Poll.t(),
          poll_votes: [Claper.Polls.PollVote.t()],
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @derive {Jason.Encoder, only: [:content, :vote_count]}
  schema "poll_opts" do
    field :content, :string
    field :vote_count, :integer

    # Set on the buckets of a :slider poll, which keeps one option per rating
    # value of its range, and nil on the choices of a :choice poll. The pair
    # (poll_id, rating_value) is unique in the database.
    field :rating_value, :integer

    field :percentage, :float, virtual: true

    belongs_to :poll, Claper.Polls.Poll
    has_many :poll_votes, Claper.Polls.PollVote, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(poll_opt, attrs) do
    poll_opt
    |> cast(attrs, [:content, :vote_count, :poll_id])
    |> validate_required([:content])
    |> validate_length(:content, max: 255)
  end

  @doc """
  The changeset of a rating bucket. `rating_value` is the key the database
  identifies a slider poll's buckets by and it is written by
  `Claper.Polls.submit_rating/4` alone, never by whoever fills in the poll form,
  so it stays out of the public `changeset/2` above.
  """
  def rating_changeset(poll_opt, attrs) do
    poll_opt
    |> changeset(attrs)
    |> cast(attrs, [:rating_value])
    |> validate_required([:rating_value])
    |> unique_constraint(:rating_value, name: :poll_opts_poll_id_rating_value_index)
  end
end
