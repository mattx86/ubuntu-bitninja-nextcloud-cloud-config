#!/bin/bash
#
# BitNinja Final Configuration
# This script runs AFTER all other deployment steps to ensure BitNinja configs are generated
# 
# This is necessary because BitNinja needs time to stabilize after initial installation
# before it can properly generate SSL termination config files.
#

set -e

# Source configuration
source /root/system-setup/config.sh

log_and_console "=== BITNINJA FINAL CONFIGURATION ==="
log_and_console "Ensuring BitNinja SSL termination is properly configured..."

# Check if certificate exists
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  log_and_console "⚠ No SSL certificate found for $DOMAIN"
  log_and_console "Please run: sudo /root/system-setup/scripts/_8_ssl_certificate.sh"
  exit 1
fi

# Check if BitNinja is running
if ! systemctl is-active --quiet bitninja; then
  log_and_console "⚠ BitNinja is not running, starting it..."
  systemctl start bitninja
  sleep 10
fi

# Check if config files already exist
if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
  log_and_console "✓ BitNinja config files already exist"
  log_and_console "Checking if BitNinja is listening on port 443..."
  
  if ss -tlnp | grep -q ':443.*bitninja'; then
    log_and_console "✓ BitNinja already listening on port 443"
    log_and_console "No further action needed"
    exit 0
  else
    log_and_console "⚠ Config files exist but BitNinja not listening on 443"
    log_and_console "Will regenerate configs..."
  fi
fi

# Add certificate to BitNinja (this will work now that system is stable)
log_and_console "Adding SSL certificate to BitNinja..."
CERT_OUTPUT=$(bitninjacli --module=SslTerminating --add-cert \
  --domain=$DOMAIN \
  --certFile=/etc/letsencrypt/live/$DOMAIN/fullchain.pem \
  --keyFile=/etc/letsencrypt/live/$DOMAIN/privkey.pem 2>&1)

log_and_console "Certificate addition output: $CERT_OUTPUT"

# Force recollection
log_and_console "Forcing certificate recollection..."
bitninjacli --module=SslTerminating --force-recollect

# Restart BitNinja
log_and_console "Restarting BitNinja to generate config files..."
systemctl restart bitninja

# Wait for config generation (should be fast now that system is stable)
log_and_console "Waiting for config file generation..."
WAIT_COUNT=0
while [ ! -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ] && [ $WAIT_COUNT -lt 60 ]; do
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
  log_and_console "✓ Config files generated after ${WAIT_COUNT} seconds"
else
  log_and_console "⚠ Config files not generated after 60 seconds"
  log_and_console "This is unusual. Please check BitNinja logs:"
  log_and_console "  tail -50 /var/log/bitninja/error.log"
  exit 1
fi

# Fix backend configuration
log_and_console "Configuring BitNinja backend and removing IPv6..."

# Remove immutable flags
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Fix backend to point to Apache
sed -i 's/server[[:space:]]\+origin-backend[[:space:]]\+\*:443.*/server\torigin-backend 127.0.0.1:80 check backup/' \
  /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg

# Remove IPv6 binds
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Fix internal port bindings
sed -i 's/bind \*:60415/bind 127.0.0.1:60415/' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
sed -i 's/bind \*:60418/bind 127.0.0.1:60418/' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Make configs immutable
chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg
chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

log_and_console "✓ Backend configured to forward to Apache (127.0.0.1:80)"
log_and_console "✓ IPv6 binds removed"
log_and_console "✓ Config files made immutable"

# Final restart
log_and_console "Performing final BitNinja restart..."
systemctl restart bitninja
sleep 10

# Verify
log_and_console "Verifying configuration..."

if ss -tlnp | grep -q ':443.*bitninja'; then
  log_and_console "✓ BitNinja listening on port 443"
else
  log_and_console "⚠ BitNinja NOT listening on port 443"
  exit 1
fi

# Check for IPv6
IPV6_COUNT=$(ss -tlnp | grep bitninja | grep -c '\[::\]' || true)
if [ "$IPV6_COUNT" -eq 0 ]; then
  log_and_console "✓ No IPv6 binds detected"
else
  log_and_console "⚠ WARNING: Found $IPV6_COUNT IPv6 binds"
fi

# Test HTTPS
log_and_console "Testing HTTPS access..."
if curl -I -s -k https://$DOMAIN/ | grep -q "HTTP/2"; then
  log_and_console "✓ HTTPS working correctly"
else
  log_and_console "⚠ HTTPS test failed"
fi

log_and_console ""
log_and_console "=== BITNINJA FINAL CONFIGURATION COMPLETE ==="
log_and_console "✓ BitNinja SSL termination is now fully configured"
log_and_console "✓ Your Nextcloud is accessible at: https://$DOMAIN/"

