#!/usr/bin/env bash

set -e

source "constants.sh"

USE_EXAMPLE=false

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --script-example) USE_EXAMPLE=true ;;
        *) echo "Unknown parameter passed: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$USE_EXAMPLE" = true ]; then
    docker run --rm \
        -p 5900:5900 \
        --device=/dev/kvm \
        --stop-timeout 120 \
        -v "$HOST_PATH"/examples/PythonScript.ps1:/root/win-docker/samba/PythonScript.ps1 \
        $DOCKERHUB_USER/$APP_NAME:latest \
        'powershell -ExecutionPolicy Bypass -File "\\10.0.2.4\qemu\PythonScript.ps1"'
else
    docker run --rm -it \
        -p 5900:5900 \
        --device=/dev/kvm \
        --stop-timeout 120 \
        $DOCKERHUB_USER/$APP_NAME:latest
fi