export $(cat .env | xargs)

args=("$@")

if [ "${args[0]}" == "test" ]; then
  mix test
elif [ "${args[0]}" == "start" ]; then
  mix phx.server
fi

