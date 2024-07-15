#!/usr/bin/env bash

python3 write-quickemu-conf.py
quickemu --vm windows-11.conf --public-dir /root/win-docker/samba --display none --extra_args "-vnc :0"