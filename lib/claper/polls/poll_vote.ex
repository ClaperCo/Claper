defmodule Claper.Polls.PollVote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "poll_votes" do
    field :attendee_identifier, :string

    belongs_to :poll, Claper.Polls.Poll
    belongs_to :poll_opt, Claper.Polls.PollOpt
    belongs_to :user, Claper.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(poll_vote, attrs) do
    poll_vote
    |> cast(attrs, [:attendee_identifier, :user_id, :poll_opt_id, :poll_id])
    |> validate_required([:poll_opt_id, :poll_id])
  end
end
