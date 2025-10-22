#!/bin/bash
# Firewall Configuration Script
# Configures UFW firewall rules

source /root/system-setup/config.sh
log_and_console "=== FIREWALL CONFIGURATION ==="
log_and_console "Configuring UFW firewall..."

# Disable IPv6 in UFW if IPv6 is disabled system-wide
if [ "$DISABLE_IPV6" = "true" ]; then
  sed -i 's/IPV6=yes/IPV6=no/' /etc/default/ufw
  log_and_console "✓ UFW IPv6 disabled"
fi

# Set default policies BEFORE enabling UFW
ufw --force default deny incoming
ufw --force default allow outgoing
ufw --force default allow routed

# Enable UFW
ufw --force enable

# Add firewall rules
if [ "$DISABLE_IPV6" = "true" ]; then
  # IPv4-only rules
  ufw allow proto tcp from any to any port "$UFW_SSH_PORT" comment 'SSH administration (IPv4)'
  ufw allow proto tcp from any to any port 80 comment 'HTTP - Lets Encrypt challenges (IPv4)'
  ufw allow proto tcp from any to any port "$UFW_HTTPS_PORT" comment 'HTTPS - BitNinja WAF (IPv4)'
else
  # Standard rules (IPv4 + IPv6)
  ufw allow "$UFW_SSH_PORT/tcp" comment 'SSH administration'
  ufw allow 80/tcp comment 'HTTP - Lets Encrypt challenges'
  ufw allow "$UFW_HTTPS_PORT/tcp" comment 'HTTPS - BitNinja WAF'
fi

# Allow all traffic on loopback interface (localhost)
ufw allow in on lo
ufw allow out on lo
log_and_console "✓ Loopback interface allowed"

# BitNinja internal ports (localhost only - UFW allows by default via loopback)
# These ports are used by BitNinja WAF 2.0 internally on 127.0.0.1:
# 60300: WAF HTTP, 60301: WAF HTTPS
# 60414-60415: SSL Terminating (HTTPS/HTTP)
# 60416-60417: TrustedProxy
# Traffic is routed via DNAT: External 443 → 127.0.0.1:60414
log_and_console "✓ BitNinja internal ports (60300, 60301, 60414-60417) on localhost"

# Note: CaptchaHttp module is disabled, so no external Captcha ports needed

# Reload UFW to apply all changes
ufw reload

# Display UFW status for verification
log_and_console "=== UFW Status ==="
ufw status verbose | tee -a "$LOG_FILE"

log_and_console "✓ UFW configured: SSH ($UFW_SSH_PORT), HTTP (80), HTTPS ($UFW_HTTPS_PORT)"
