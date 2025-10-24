#!/bin/bash
# Security Hardening Script
# Applies comprehensive system security measures

source /root/system-setup/config.sh
log_and_console "=== SECURITY HARDENING ==="
log_and_console "Applying comprehensive system security..."

# Disable unnecessary services
systemctl disable avahi-daemon cups bluetooth snapd ModemManager 2>/dev/null || true

# Secure shared memory with tmpfs
echo 'tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,size=1G 0 0' >> /etc/fstab
echo 'tmpfs /var/tmp tmpfs defaults,nodev,nosuid,noexec,size=100M 0 0' >> /etc/fstab

# Restrict core dumps and SUID
echo '* hard core 0' >> /etc/security/limits.conf
echo 'fs.suid_dumpable = 0' >> /etc/sysctl.conf

# Network security hardening
cat >> /etc/sysctl.conf << 'EOF'
# Disable network redirects and source routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
# Enable logging and ICMP protection
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
# TCP security
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
EOF

# IPv6 disablement (must be done BEFORE SSH hardening)
if [ "$DISABLE_IPV6" = "true" ]; then
  log_and_console "Disabling IPv6 system-wide..."
  
  # Disable IPv6 via sysctl (immediate effect)
  echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.conf
  echo 'net.ipv6.conf.default.disable_ipv6 = 1' >> /etc/sysctl.conf
  echo 'net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
  
  # Apply immediately
  sysctl -w net.ipv6.conf.all.disable_ipv6=1
  sysctl -w net.ipv6.conf.default.disable_ipv6=1
  sysctl -w net.ipv6.conf.lo.disable_ipv6=1
  
  # Disable IPv6 in GRUB (permanent after reboot)
  echo 'GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"' >> /etc/default/grub
  update-grub
  
  log_and_console "✓ IPv6 disabled system-wide (active immediately)"
fi

# Apply all sysctl changes
sysctl -p

# SSH hardening (after IPv6 configuration)
cat >> /etc/ssh/sshd_config.d/ssh-hardening.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
MaxAuthTries 2
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
EOF

# Configure SSH to respect IPv6 setting
if [ "$DISABLE_IPV6" = "true" ]; then
  echo 'AddressFamily inet' >> /etc/ssh/sshd_config.d/ssh-hardening.conf
  log_and_console "✓ SSH configured for IPv4 only"
  
  # Disable SSH socket activation to prevent IPv6 binding
  # systemd socket activation creates IPv6 sockets even when IPv6 is disabled
  systemctl stop ssh.socket 2>/dev/null || true
  systemctl disable ssh.socket 2>/dev/null || true
  log_and_console "✓ SSH socket activation disabled"
else
  echo 'AddressFamily any' >> /etc/ssh/sshd_config.d/ssh-hardening.conf
  log_and_console "✓ SSH configured for IPv4 and IPv6"
fi

# Ensure SSH service is enabled on boot (not just the socket)
systemctl enable ssh
log_and_console "✓ SSH service enabled on boot"

# Restart SSH to apply hardening immediately (Ubuntu uses 'ssh' not 'sshd')
systemctl restart ssh
log_and_console "✓ SSH hardening applied and service restarted"

log_and_console "Configuring fail2ban..."

# Download fail2ban configurations
wget --tries=3 --timeout=30 -O /etc/fail2ban/jail.local "$GITHUB_RAW_URL/conf/fail2ban-jail.local" || { log_and_console "ERROR: Failed to download fail2ban-jail.local"; exit 1; }
chown root:root /etc/fail2ban/jail.local
chmod 644 /etc/fail2ban/jail.local
sed -i "s|\$UFW_SSH_PORT|$UFW_SSH_PORT|g" /etc/fail2ban/jail.local
sed -i "s|\$UFW_HTTPS_PORT|$UFW_HTTPS_PORT|g" /etc/fail2ban/jail.local
sed -i "s|\$BITNINJA_CAPTCHA_PORT_1|$BITNINJA_CAPTCHA_PORT_1|g" /etc/fail2ban/jail.local
sed -i "s|\$BITNINJA_CAPTCHA_PORT_2|$BITNINJA_CAPTCHA_PORT_2|g" /etc/fail2ban/jail.local
sed -i "s|\$NEXTCLOUD_WEB_DIR|$NEXTCLOUD_WEB_DIR|g" /etc/fail2ban/jail.local

# Download filter configurations
wget --tries=3 --timeout=30 -O /etc/fail2ban/filter.d/nextcloud.conf "$GITHUB_RAW_URL/conf/fail2ban-nextcloud.conf" || { log_and_console "ERROR: Failed to download fail2ban-nextcloud.conf"; exit 1; }
chown root:root /etc/fail2ban/filter.d/nextcloud.conf
chmod 644 /etc/fail2ban/filter.d/nextcloud.conf
wget --tries=3 --timeout=30 -O /etc/fail2ban/filter.d/bitninja-waf.conf "$GITHUB_RAW_URL/conf/fail2ban-bitninja-waf.conf" || { log_and_console "ERROR: Failed to download fail2ban-bitninja-waf.conf"; exit 1; }
chown root:root /etc/fail2ban/filter.d/bitninja-waf.conf
chmod 644 /etc/fail2ban/filter.d/bitninja-waf.conf
wget --tries=3 --timeout=30 -O /etc/fail2ban/filter.d/bitninja-captcha.conf "$GITHUB_RAW_URL/conf/fail2ban-bitninja-captcha.conf" || { log_and_console "ERROR: Failed to download fail2ban-bitninja-captcha.conf"; exit 1; }
chown root:root /etc/fail2ban/filter.d/bitninja-captcha.conf
chmod 644 /etc/fail2ban/filter.d/bitninja-captcha.conf

systemctl start fail2ban && systemctl enable fail2ban
log_and_console "✓ fail2ban configured for SSH, BitNinja, and BitNinja protection"

log_and_console "Downloading unattended upgrades configuration..."
wget --tries=3 --timeout=30 -O /etc/apt/apt.conf.d/50unattended-upgrades "$GITHUB_RAW_URL/conf/50ubuntu-unattended-upgrades" || { log_and_console "ERROR: Failed to download 50ubuntu-unattended-upgrades"; exit 1; }
chown root:root /etc/apt/apt.conf.d/50unattended-upgrades
chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades
log_and_console "✓ Automatic security updates configured"

log_and_console "✓ Security hardening completed"
