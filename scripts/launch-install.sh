#!/usr/bin/env bash

set -e

source "constants.sh"

# start reverse port forwarding for vnc
ssh -fN -R 5900:localhost:5900 linuxserver.io@"$VNC_CONTAINER_NAME" -p 2222 -o StrictHostKeyChecking=no

# start quickemu
./launch-quickemu.sh

# keep polling until ssh is accessible (i.e. installation & post-install config is complete)
# => allow 2 hours for the install to complete
./poll-ssh.sh -h "$SSH_HOST" -a 240 -d 30

# set-up key-based authentication in the windows image
./copy-public-key.sh

# installation and post-install config is complete => shutdown
ssh "$SSH_HOST" 'shutdown /s /t 0'

# wait until the qemu process has cleanly terminated
./wait-for-process.sh "$QUICKEMU_PROC" 120

# remove the installation iso from the docker image
rm windows-11/windows-11.iso