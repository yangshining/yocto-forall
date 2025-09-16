#!/bin/sh

# Network setup script

# Set network interface
ifconfig eth0 192.168.1.100 netmask 255.255.255.0 up

# Set gateway
route add default gw 192.168.1.1
