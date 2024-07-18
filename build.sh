#!/usr/bin/env bash

CONSTANTS_FILE="constants.sh"

if [[ ! -f "$CONSTANTS_FILE" ]]; then
    echo "Error: Constants file not found: $CONSTANTS_FILE" >&2
    exit 1
fi

source "$CONSTANTS_FILE"

PUSH_IMAGE=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --push) PUSH_IMAGE=true ;;
        *) echo "Unknown parameter passed: $1" >&2; exit 1 ;;
    esac
    shift
done

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
    lscr.io/linuxserver/openssh-server:latest > /dev/null

# check if the builder already exists, instantiate it if not, and bind to the same custom network
docker buildx inspect $BUILDER_ID &>/dev/null || docker buildx create \
    --name $BUILDER_ID \
    --driver docker-container \
    --driver-opt network=$NETWORK_NAME \
    --driver-opt env.BUILDKIT_STEP_LOG_MAX_SIZE=10485760 \
    --buildkitd-flags '--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host'

# Extract version from cz.toml
VERSION=$(grep 'version = ' .cz.toml | sed 's/version = //;s/"//g')
echo "Building version: $VERSION"

docker buildx build . \
    -t $DOCKERHUB_USER/$APP_NAME:$VERSION  \
    --load \
    --builder=$BUILDER_ID \
    --allow security.insecure \
    --allow network.host

build_status=$?

docker stop $VNC_CONTAINER_NAME > /dev/null

if [ $build_status -ne 0 ]; then
    echo "Error: Build did not complete successfully" >&2
    exit 1
fi

# Tag the image as latest
docker tag $DOCKERHUB_USER/$APP_NAME:$VERSION $DOCKERHUB_USER/$APP_NAME:latest

if  [ "$PUSH_IMAGE" = true ]; then    
    echo "Pushing image to Docker Hub..."

    # Push the versioned image
    if ! docker push $DOCKERHUB_USER/$APP_NAME:$VERSION; then
        echo "Error: Failed to push $DOCKERHUB_USER/$APP_NAME:$VERSION" >&2
        exit 1
    fi

    # Push the latest tag
    if ! docker push $DOCKERHUB_USER/$APP_NAME:latest; then
        echo "Error: Failed to push $DOCKERHUB_USER/$APP_NAME:latest" >&2
        exit 1
    fi

    echo "Successfully built and pushed $DOCKERHUB_USER/$APP_NAME:$VERSION and $DOCKERHUB_USER/$APP_NAME:latest"
fi