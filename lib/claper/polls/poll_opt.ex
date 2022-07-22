defmodule Claper.Polls.PollOpt do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:content, :vote_count]}
  schema "poll_opts" do
    field :content, :string
    field :vote_count, :integer
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
  end
end
