#!/bin/bash

set -a

# Default environment file
env_file=".env"

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --env)
      env_file="$2"
      shift 2  # Skip the next argument as it's the value for --env
      ;;
    *)
      break  # Exit the loop if an unrecognized option is found
      ;;
  esac
done

source "$env_file"
set +a

# Remaining arguments are treated as the command to run
args=("$@")

# Check if no command is provided
if [ ${#args[@]} -eq 0 ]; then
  echo "Usage: $0 [--env path/to/env] <command>"
  echo "Example: $0 mix phx.server"
  echo "Example: $0 --env path/to/env mix phx.server"
  exit 1
fi

# Execute the command
"${args[@]}"
