#!/bin/bash -e

# Install necessary packages
install -m 755 files/install.sh ${ROOTFS_DIR}/tmp/
on_chroot << EOF
chmod +x /tmp/install.sh
/tmp/install.sh
EOF

# Copy configuration files
install -m 644 files/hostapd.conf ${ROOTFS_DIR}/etc/hostapd/hostapd.conf
install -m 644 files/dnsmasq.conf ${ROOTFS_DIR}/etc/dnsmasq.conf
install -m 644 files/nodogsplash.conf ${ROOTFS_DIR}/etc/nodogsplash/nodogsplash.conf
install -d ${ROOTFS_DIR}/var/www/html/
install -m 644 files/index.html ${ROOTFS_DIR}/var/www/html/index.html
install -m 644 files/my-ap.service ${ROOTFS_DIR}/etc/systemd/system/my-ap.service

# Configure system to use our configs
on_chroot << EOF
# Enable services
systemctl enable my-ap.service
systemctl enable dnsmasq.service
systemctl enable hostapd.service
systemctl enable lighttpd.service

# Allow IPv4 forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

# Disable dhcpcd on wlan0
if grep -q "denyinterfaces wlan0" /etc/dhcpcd.conf; then
    echo "wlan0 already denied in dhcpcd.conf"
else
    echo "denyinterfaces wlan0" >> /etc/dhcpcd.conf
fi

# Make hostapd use our config file
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd
EOF
