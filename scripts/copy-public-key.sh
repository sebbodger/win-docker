#!/usr/bin/env bash

# Path to your public key
public_key="/root/.ssh/id_rsa.pub"

# Check if the public key exists
if [ ! -f "$public_key" ]; then
    echo "Public key not found at $public_key"
    echo "Generate a key pair using ssh-keygen or specify the correct path."
    exit 1
fi

# Read the content of the public key
key_content=$(cat "$public_key")

# Prepare the commands to be executed on the Windows machine
write_key="powershell.exe -Command \"Add-Content -Path C:/ProgramData/ssh/administrators_authorized_keys -Value '$key_content' -Encoding ASCII\""
set_permissions="icacls.exe C:/ProgramData/ssh/administrators_authorized_keys /inheritance:r /grant \"Administrators:F\" /grant \"SYSTEM:F\""

# Use SSH to execute the commands on the remote Windows machine
# exp "quickemu" ssh quickemu@localhost -p 22220 "$write_key && $set_permissions"
sshpass -p "quickemu" ssh quickemu@localhost -p 22220 "$write_key && $set_permissions"

# Check if the SSH command was successful
if [ $? -eq 0 ]; then
    echo "Public key successfully copied to the remote Windows machine."
else
    echo "Failed to copy the public key. Please check your credentials and try again."
    exit 1
fi

echo "Waiting for changes to take effect..."
sleep 5

echo "Testing SSH connection with the new key..."
ssh quickemu@localhost -p 22220 exit

if [ $? -eq 0 ]; then
    echo "SSH connection successful. Key-based authentication is working."
else
    echo "SSH connection failed. Please check your configuration and try again."
    exit 1
fi