#!/usr/bin/env bash

CONTAINER_TAG="win-docker"
VNC_CONTAINER_NAME="vnc-win-install-watcher"
NETWORK_NAME="win-docker-builder"
BUILDER_ID="builder-37996e70662e58b06"

# check if the network already exists, instantiate it if not
docker network inspect $NETWORK_NAME &>/dev/null || docker network create $NETWORK_NAME

# start the ssh server used for vnc (reverse) port forwarding and bind to the custom network
docker run \
    --name $VNC_CONTAINER_NAME \
    --network $NETWORK_NAME \
    -d --rm \
    -e PUBLIC_KEY="$(cat ssh/id_rsa.pub)" \
    -p 5905:5900 \
    -p 2222:2222 \
    -p 8080:8080 \
    --mount type=bind,source="$HOST_PATH"/openssh-config,target=/custom-cont-init.d,readonly \
    lscr.io/linuxserver/openssh-server:latest

# check if the builder already exists, instantiate it if not, and bind to the same custom network
docker buildx inspect $BUILDER_ID &>/dev/null || docker buildx create \
    --name $BUILDER_ID \
    --driver docker-container \
    --driver-opt network=$NETWORK_NAME \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10485760 \
    --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host'

docker buildx build . \
    -t $CONTAINER_TAG \
    --load \
    --builder=$BUILDER_ID \
    --allow security.insecure \
    --allow network.host

docker stop $VNC_CONTAINER_NAME