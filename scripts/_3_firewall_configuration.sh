#!/bin/bash
# Firewall Configuration Script
# Configures UFW firewall rules

source /root/system-setup/config.sh
log_and_console "=== FIREWALL CONFIGURATION ==="
log_and_console "Configuring UFW firewall..."
ufw --force enable && ufw default deny incoming && ufw default allow outgoing
ufw allow "$UFW_SSH_PORT/tcp" comment 'SSH administration'
ufw allow "$UFW_HTTPS_PORT/tcp" comment 'HTTPS (BitNinja WAF)'
ufw allow "$BITNINJA_CAPTCHA_PORT_1/tcp" comment 'BitNinja Captcha Port 1'
ufw allow "$BITNINJA_CAPTCHA_PORT_2/tcp" comment 'BitNinja Captcha Port 2'
ufw reload
log_and_console "✓ UFW configured: SSH ($UFW_SSH_PORT), HTTPS ($UFW_HTTPS_PORT), BitNinja Captcha ports"
