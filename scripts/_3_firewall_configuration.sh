#!/bin/bash
# Firewall Configuration Script
# Configures UFW firewall rules

source /root/system-setup/config.sh
log_and_console "=== FIREWALL CONFIGURATION ==="
log_and_console "Configuring UFW firewall..."
ufw --force enable && ufw default deny incoming && ufw default allow outgoing
ufw allow "$UFW_SSH_PORT/tcp" comment 'SSH administration'
ufw allow 80/tcp comment 'HTTP (Let'\''s Encrypt challenges)'
ufw allow "$UFW_HTTPS_PORT/tcp" comment 'HTTPS (BitNinja WAF)'

# BitNinja internal ports (localhost only - UFW allows by default)
# These ports are used by BitNinja WAF Pro internally:
# 60300: WAF HTTP, 60301: WAF HTTPS
# 60414-60415: SSL Terminating, 60416-60417: TrustedProxy
log_and_console "✓ BitNinja internal ports (60300, 60301, 60414-60417) allowed on localhost"

# BitNinja Captcha ports (MUST be externally accessible)
# Only allow 60413 (CaptchaHttps) - CaptchaHttp (60412) not needed for HTTPS-only setup
ufw allow "$BITNINJA_CAPTCHA_PORT_2/tcp" comment 'BitNinja CaptchaHttps'

ufw reload
log_and_console "✓ UFW configured: SSH ($UFW_SSH_PORT), HTTPS ($UFW_HTTPS_PORT), BitNinja Captcha ports"
