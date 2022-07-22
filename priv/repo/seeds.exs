# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Claper.Repo.insert!(%Claper.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

user =
  %Claper.Accounts.User{
    email: "admin@example.com",
    confirmed_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
    inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
    updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
    is_admin: true
  }
  |> Claper.Repo.insert!()
