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

# Add firewall rules with explicit destination IP
# These rules work for both IPv4-only and IPv4+IPv6 configurations
ufw allow proto tcp from any to "$SERVER_IP" port "$UFW_SSH_PORT" comment 'SSH administration'
ufw allow proto tcp from any to "$SERVER_IP" port "$UFW_HTTP_PORT" comment 'HTTP - Lets Encrypt challenges'
ufw allow proto tcp from any to "$SERVER_IP" port "$UFW_HTTPS_PORT" comment 'HTTPS - BitNinja WAF'
ufw allow proto tcp from any to "$SERVER_IP" port "$UFW_CAPTCHA_PORT" comment 'HTTPS Captcha - BitNinja (if enabled)'

# Allow all traffic on loopback interface (localhost)
ufw allow in on lo
ufw allow out on lo
log_and_console "✓ Loopback interface allowed"

# BitNinja internal ports (localhost only - UFW allows by default via loopback)
# These ports are used by BitNinja WAF 2.0 internally on 127.0.0.1:
# 60300: WAF HTTP, 60301: WAF HTTPS
# 60414-60415: SSL Terminating backend ports
# 60416-60417: TrustedProxy
# BitNinja listens on SERVER_IP:443 (external), Apache on 127.0.0.1:443 (backend)
log_and_console "✓ BitNinja internal ports (60300, 60301, 60414-60417) on localhost"

# Note: Port 60413 (HTTPS Captcha) is opened in UFW above
# CaptchaHttp module is disabled by default, but HttpsCaptcha can be enabled if needed

# Reload UFW to apply all changes
ufw reload

# Display UFW status for verification
log_and_console "=== UFW Status ==="
ufw status verbose | tee -a "$LOG_FILE"

log_and_console "✓ UFW configured: SSH ($UFW_SSH_PORT), HTTP ($UFW_HTTP_PORT), HTTPS ($UFW_HTTPS_PORT), HTTPS Captcha ($UFW_CAPTCHA_PORT)"
