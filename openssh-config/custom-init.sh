#!/bin/bash

# enable GatewayPorts and TcpForwarding
sed -i -e 's/^#\?GatewayPorts .*/GatewayPorts yes/' \
       -e 's/^#\?AllowTcpForwarding .*/AllowTcpForwarding yes/' \
       /etc/ssh/sshd_config