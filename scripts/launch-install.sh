#!/usr/bin/env bash

set -e

# ssh -fN -R 8080:localhost:8080 linuxserver.io@vnc-win-install-watcher -p 2222 -o StrictHostKeyChecking=no
# python3 -c $'from http.server import BaseHTTPRequestHandler, HTTPServer\nclass Handler(BaseHTTPRequestHandler):\n    def do_GET(self):\n        self.send_response(200)\n        self.send_header("Content-type", "text/plain")\n        self.end_headers()\n        self.wfile.write(b"Hello world")\nHTTPServer(("", 8080), Handler).serve_forever()'

# start reverse port forwarding for vnc
ssh -fN -R 5900:localhost:5900 linuxserver.io@vnc-win-install-watcher -p 2222 -o StrictHostKeyChecking=no

# start quickemu
./launch-quickemu.sh

# keep polling until ssh is accessible (i.e. installation & post-install config is complete)
# => allow 2 hours for the install to complete
./poll-ssh.sh -a 240 -d 30

# set-up key-based authentication in the windows image
./copy-public-key.sh

# installation and post-install config is complete => shutdown
ssh quickemu@localhost -p 22220 'shutdown /s /t 0'

# wait until the qemu process has cleanly terminated
./wait-for-process.sh windows-11 120

# remove the installation iso from the docker image
rm windows-11/windows-11.iso