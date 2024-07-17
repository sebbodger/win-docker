#!/usr/bin/env bash

docker run -it -p 5900:5900 --device=/dev/kvm --stop-timeout 120 win-docker:latest