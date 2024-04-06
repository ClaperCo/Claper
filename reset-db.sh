docker stop claper-db
docker rm claper-db
docker run -p 5432:5432 -e POSTGRES_PASSWORD=claper -e POSTGRES_USER=claper -e POSTGRES_DB=claper --name claper-db -d postgres:15
sleep 5
mix ecto.migrate
mix run priv/repo/seeds.exs