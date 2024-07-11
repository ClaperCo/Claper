set -a
source .env
set +a

args=("$@")

if [ "${args[0]}" == "start" ]; then
  mix phx.server
else
  mix "$@"
fi

