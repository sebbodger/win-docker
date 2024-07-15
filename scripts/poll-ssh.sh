#!/usr/bin/env bash

# Default values
readonly DEFAULT_MAX_ATTEMPTS=10
readonly DEFAULT_DELAY=5
readonly DEFAULT_HOST="localhost"
readonly DEFAULT_PORT=22220

# Usage
usage() {
  echo "Usage: $0 [-a MAX_ATTEMPTS] [-d DELAY] [-h HOST] [-p PORT]"
  echo "  -a MAX_ATTEMPTS   Maximum number of attempts (default: $DEFAULT_MAX_ATTEMPTS)"
  echo "  -d DELAY          Delay between attempts in seconds (default: $DEFAULT_DELAY)"
  echo "  -h HOST           SSH server hostname or IP address (default: $DEFAULT_HOST)"
  echo "  -p PORT           SSH server port (default: $DEFAULT_PORT)"
  exit 1
}

# Initialize variables with default values
max_attempts="$DEFAULT_MAX_ATTEMPTS"
delay="$DEFAULT_DELAY"
host="$DEFAULT_HOST"
port="$DEFAULT_PORT"

# Parse arguments
while getopts ":a:d:h:p:" opt; do
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
      host="$OPTARG"
      ;;
    p)
      if ((OPTARG <= 0)); then
        echo "Error: Invalid value for -p. Must be a positive integer."
        usage
      fi
      port="$OPTARG"
      ;;
    *)
      echo "Error: Unknown option -$OPTARG"
      usage
      ;;
  esac
done

# Wait for SSH server to be available
# https://stackoverflow.com/questions/35741323/how-to-find-if-remote-host-is-reachable-over-ssh-without-actually-doing-ssh

for ((attempt_count=1; attempt_count<=max_attempts; attempt_count++)); do
  if ssh $host -p $port \
    -o ConnectTimeout=2 \
    -o PubkeyAuthentication=no \
    -o PasswordAuthentication=no \
    -o KbdInteractiveAuthentication=no \
    -o ChallengeResponseAuthentication=no \
    -o BatchMode=true 2>&1 | fgrep -q "Permission denied"; 
  then
    echo "Connected to SSH server $host:$port"
    exit 0
  fi
  sleep "$delay"
done

echo "Error: Failed to connect to SSH server after $max_attempts attempts."
exit 1