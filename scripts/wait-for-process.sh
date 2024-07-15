#!/usr/bin/env bash

usage() {
  echo "Usage: $0 <process_name> <timeout_in_seconds>"
  exit 1
}

if (( $# != 2 )); then
  usage
fi

readonly process_name="$1"
readonly timeout="$2"

if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
  echo "Error: Timeout must be a positive integer."
  usage
fi

readonly start_time=$(date +%s)
readonly end_time=$((start_time + timeout))

while pgrep -x "$process_name" >/dev/null; do
  if (( $(date +%s) >= end_time )); then
    echo "Timeout reached. Process '$process_name' is still running."
    exit 1
  fi
  sleep 1
done

echo "Process '$process_name' has terminated."