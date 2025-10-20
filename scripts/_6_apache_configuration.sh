#!/bin/bash
# Apache Web Server Setup Script
# Configures Apache with security hardening

source /root/system-setup/config.sh
log_and_console "=== APACHE WEB SERVER SETUP ==="

log_and_console "Configuring Apache modules and localhost binding..."

# Ensure mpm_prefork is enabled (required for mod_php)
# Disable event/worker if enabled, enable prefork
a2dismod mpm_event mpm_worker 2>/dev/null || true
a2enmod mpm_prefork 2>/dev/null || log_and_console "✓ mpm_prefork already enabled"

# Enable required modules (including SSL for ConfigParser), disable status module, disable default site
a2enmod rewrite headers env dir mime setenvif remoteip ssl && a2dismod status && a2dissite 000-default.conf
log_and_console "✓ Apache SSL module enabled (for BitNinja ConfigParser certificate detection)"

# Configure Apache for localhost-only binding on port 443 (BitNinja WAF forwards decrypted HTTPS)
# Disable port 80 completely
sed -i 's/^Listen 80$/#Listen 80/' /etc/apache2/ports.conf

# Configure port 443 to listen on localhost only
sed -i 's/^\([[:space:]]*\)Listen 443$/\1Listen 127.0.0.1:443/' /etc/apache2/ports.conf

log_and_console "✓ Apache configured for localhost-only binding (127.0.0.1:443)"
log_and_console "✓ Apache port 80 disabled (only HTTPS on localhost)"

log_and_console "Configuring Apache MPM prefork for memory efficiency..."
# Configure Apache MPM prefork to prevent memory exhaustion
# Each Apache worker with mod_php uses: ~50MB base + PHP_MEMORY_LIMIT
# For 8GB system: Allow max 32 workers = ~32 × (50MB + 256MB) = ~9.8GB peak
cat > /etc/apache2/mods-available/mpm_prefork.conf <<'EOF'
<IfModule mpm_prefork_module>
    StartServers             5
    MinSpareServers          5
    MaxSpareServers         10
    MaxRequestWorkers       32
    MaxConnectionsPerChild 1000
</IfModule>
EOF
log_and_console "✓ Apache MPM prefork configured for controlled memory usage"

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

log_and_console "Starting and enabling Apache..."
systemctl enable apache2
systemctl restart apache2
