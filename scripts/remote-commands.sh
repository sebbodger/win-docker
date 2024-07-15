#!/usr/bin/env bash

# Set the SSH connection details
remote_host="example.com"
remote_user="username"
remote_port="22"

# Check if the remote commands argument is provided
if [[ $# -eq 0 ]]; then
  echo "Please provide the list of remote commands as an argument."
  echo "Usage: $0 \"command1\" \"command2\" \"command3\" ..."
  exit 1
fi

# Store the remote commands in an array
mapfile -t remote_commands < <(printf '%s\n' "$@")

# Connect to the SSH server and run the commands
ssh -p "$remote_port" "$remote_user@$remote_host" << EOF
  set -euo pipefail  # Exit on error, unset variables, and fail on pipe errors

  # Run each command in serial and capture the output
  for command in "\${remote_commands[@]}"; do
    echo "Executing command: \$command"
    output=\$(cmd.exe /c "\$command" 2>&1)
    echo "\$output"
    echo "------------------------"
  done
EOF

# Check the exit status of the SSH command
if [[ $? -eq 0 ]]; then
  echo "All commands executed successfully on the remote Windows server."
else
  echo "Failed to execute one or more commands on the remote Windows server."
  exit 1
fi