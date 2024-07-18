#!/usr/bin/env bash

CONSTANTS_FILE="constants.sh"

if [[ ! -f "$CONSTANTS_FILE" ]]; then
    echo "Error: Constants file not found: $CONSTANTS_FILE" >&2
    exit 1
fi

source "$CONSTANTS_FILE"

# Path to your public key
public_key="/root/.ssh/id_rsa.pub"

# Check if the public key exists
if [ ! -f "$public_key" ]; then
    echo "Public key not found at $public_key" >&2
    exit 1
fi

# Read the content of the public key
key_content=$(cat "$public_key")

# Prepare the commands to be executed on the Windows machine
write_key="powershell.exe -Command \"Add-Content -Path C:/ProgramData/ssh/administrators_authorized_keys -Value '$key_content' -Encoding ASCII\""
set_permissions="icacls.exe C:/ProgramData/ssh/administrators_authorized_keys /inheritance:r /grant \"Administrators:F\" /grant \"SYSTEM:F\""

# Use SSH to execute the commands on the remote Windows machine
if sshpass -p "$SSH_PASS" ssh "$SSH_HOST" "$write_key && $set_permissions"; then
    echo "Public key successfully copied to the remote Windows machine."
else
    echo "Failed to copy the public key. Please check your credentials and try again." >&2
    exit 1
fi

echo "Waiting for changes to take effect..."
sleep 5

echo "Testing SSH connection with the new key..."
if ssh "$SSH_HOST" exit; then
    echo "SSH connection successful. Key-based authentication is working."
else
    echo "SSH connection failed. Please check your configuration and try again." >&2
    exit 1
fi