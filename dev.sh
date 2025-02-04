#!/bin/bash
set -a
source .env
set +a

args=("$@")

if [ "${args[0]}" == "start" ]; then
  mix phx.server
elif [ "${args[0]}" == "iex" ]; then
  iex -S mix
else
  mix "$@"
fi

