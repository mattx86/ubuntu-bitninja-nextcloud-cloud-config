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

# Configure Apache for localhost-only binding (BitNinja WAF handles external HTTPS)
sed -i 's/Listen 80/Listen 127.0.0.1:80/' /etc/apache2/ports.conf
sed -i 's/Listen 443/Listen 127.0.0.1:443/' /etc/apache2/ports.conf
log_and_console "✓ Apache configured for localhost-only binding"

log_and_console "Applying Apache security hardening..."
sed -i 's/^ServerTokens.*/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
sed -i 's/^ServerSignature.*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
a2enconf security
log_and_console "✓ Apache security hardening applied"
