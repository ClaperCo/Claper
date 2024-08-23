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

# create a default active lti_1p3 jwk
if !Claper.Repo.get_by(Lti13.Jwks.Jwk, id: 1) do
  %{private_key: private_key} = Lti13.Jwks.Utils.KeyGenerator.generate_key_pair()

  Lti13.Jwks.create_jwk(%{
    pem: private_key,
    typ: "JWT",
    alg: "RS256",
    kid: UUID.uuid4(),
    active: true
  })
end
