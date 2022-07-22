docker start claper-db

export $(cat .env | xargs)

mix phx.server