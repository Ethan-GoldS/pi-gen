#!/bin/bash -e

# Update package lists
apt-get update

# Install required packages
apt-get install -y hostapd dnsmasq lighttpd nodogsplash iptables docker.io

# Stop services initially to allow configuration
systemctl stop hostapd
systemctl stop dnsmasq
systemctl stop lighttpd
systemctl stop nodogsplash

# Ensure lighttpd listens on all interfaces
sed -i 's/^server.bind = .*/server.bind = "0.0.0.0"/' /etc/lighttpd/lighttpd.conf

echo "Installation completed successfully"
