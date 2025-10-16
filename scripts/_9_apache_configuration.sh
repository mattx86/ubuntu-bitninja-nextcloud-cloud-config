#!/bin/bash
# Apache Web Server Setup Script
# Configures Apache with security hardening

source /root/system-setup/config.sh
log_and_console "=== APACHE WEB SERVER SETUP ==="
log_and_console "Starting and enabling Apache..."
systemctl enable apache2
systemctl restart apache2

log_and_console "Configuring Apache modules and localhost binding..."
a2enmod rewrite headers env dir mime setenvif remoteip && a2dismod status && a2dissite 000-default.conf

# Configure Apache for localhost-only binding on port 80 (BitNinja WAF handles external HTTPS)
sed -i 's/^Listen 80$/Listen 127.0.0.1:80/' /etc/apache2/ports.conf
sed -i 's/^Listen 443$/#Listen 443/' /etc/apache2/ports.conf
log_and_console "✓ Apache configured for localhost-only binding (127.0.0.1:80)"

log_and_console "Applying Apache security hardening..."
sed -i 's/^ServerTokens.*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
sed -i 's/^ServerSignature.*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
a2enconf security

# Configure Apache to log real client IPs (via mod_remoteip)
log_and_console "Configuring Apache LogFormat to use real client IPs..."
if ! grep -q 'LogFormat "%a' /etc/apache2/apache2.conf; then
  # Update LogFormat to use %a (real client IP from mod_remoteip) instead of %h
  sed -i 's/LogFormat "%h /LogFormat "%a /g' /etc/apache2/apache2.conf
  log_and_console "✓ Apache LogFormat updated to use real client IPs (%a)"
else
  log_and_console "✓ Apache LogFormat already configured for real client IPs"
fi

log_and_console "✓ Apache security hardening applied"
