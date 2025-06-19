#!/bin/bash
set -e

on_chroot << EOF
apt update
apt install -y docker.io hostapd dnsmasq lighttpd
usermod -aG docker pi
EOF

