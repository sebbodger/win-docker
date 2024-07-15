#!/usr/bin/expect

# https://stackoverflow.com/questions/12202587/automatically-enter-ssh-password-with-script

set timeout 20

set cmd [lrange $argv 1 end]
set password [lindex $argv 0]

eval spawn $cmd
expect "password:"
send "$password\r";
interact