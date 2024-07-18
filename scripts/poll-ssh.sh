#!/usr/bin/env bash

# Default values
readonly DEFAULT_MAX_ATTEMPTS=10
readonly DEFAULT_DELAY=5
readonly DEFAULT_HOST="localhost"
readonly DEFAULT_PORT=22220

# Usage
usage() {
  echo "Usage: $0 [-a MAX_ATTEMPTS] [-d DELAY] [-h HOST[:PORT]]"
  echo "  -a MAX_ATTEMPTS   Maximum number of attempts (default: $DEFAULT_MAX_ATTEMPTS)"
  echo "  -d DELAY          Delay between attempts in seconds (default: $DEFAULT_DELAY)"
  echo "  -h HOST[:PORT]    SSH server hostname or IP address, optionally with port (default: $DEFAULT_HOST:$DEFAULT_PORT)"
  exit 1
}

# Initialize variables with default values
max_attempts="$DEFAULT_MAX_ATTEMPTS"
delay="$DEFAULT_DELAY"
host="$DEFAULT_HOST"
port="$DEFAULT_PORT"

# Parse arguments
while getopts ":a:d:h:" opt; do
  case ${opt,,} in
    a)
      if ((OPTARG <= 0)); then
        echo "Error: Invalid value for -a. Must be a positive integer."
        usage
      fi
      max_attempts="$OPTARG"
      ;;
    d)
      if ((OPTARG <= 0)); then
        echo "Error: Invalid value for -d. Must be a positive integer."
        usage
      fi
      delay="$OPTARG"
      ;;
    h)
      # Split host and port if provided
      IFS=':' read -r host port <<< "$OPTARG"
      if [[ -z "$port" ]]; then
        port="$DEFAULT_PORT"
      elif ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid port number."
        usage
      fi
      ;;
    *)
      echo "Error: Unknown option -$OPTARG"
      usage
      ;;
  esac
done

# Function to construct SSH command
construct_ssh_command() {
  local ssh_cmd="ssh $host"
  if [[ "$port" != "22" ]]; then
    ssh_cmd+=" -p $port"
  fi
  ssh_cmd+=" -o ConnectTimeout=2"
  ssh_cmd+=" -o PubkeyAuthentication=no"
  ssh_cmd+=" -o PasswordAuthentication=no"
  ssh_cmd+=" -o KbdInteractiveAuthentication=no"
  ssh_cmd+=" -o ChallengeResponseAuthentication=no"
  ssh_cmd+=" -o BatchMode=true"
  echo "$ssh_cmd"
}

# Wait for SSH server to be available
for ((attempt_count=1; attempt_count<=max_attempts; attempt_count++)); do
  if eval "$(construct_ssh_command)" 2>&1 | fgrep -q "Permission denied"; then
    echo "Connected to SSH server $host:$port"
    exit 0
  fi
  sleep "$delay"
done

echo "Error: Failed to connect to SSH server after $max_attempts attempts." >&2
exit 1