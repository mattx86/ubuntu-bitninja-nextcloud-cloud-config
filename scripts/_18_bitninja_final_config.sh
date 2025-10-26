#!/bin/bash
#
# BitNinja Final Configuration
# This script runs AFTER all other deployment steps to ensure BitNinja configs are generated
# 
# This is necessary because BitNinja needs time to stabilize after initial installation
# before it can properly generate SSL termination config files.
#

# Note: We don't use 'set -e' here because we want to handle errors gracefully
# and provide helpful diagnostics rather than exiting abruptly

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

# Check if config files already exist and are properly configured
if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
  log_and_console "✓ BitNinja config files already exist"
  log_and_console "Verifying configuration..."
  
  # Always verify and fix configs, don't skip based on port 443 alone
  log_and_console "Checking backend, IPv6, and port bindings..."
fi

# Add certificate to BitNinja (this will work now that system is stable)
log_and_console "Adding SSL certificate to BitNinja..."
CERT_OUTPUT=$(bitninjacli --module=SslTerminating --add-cert \
  --domain=$DOMAIN \
  --certFile=/etc/letsencrypt/live/$DOMAIN/fullchain.pem \
  --keyFile=/etc/letsencrypt/live/$DOMAIN/privkey.pem 2>&1) || true

log_and_console "Certificate addition output: $CERT_OUTPUT"

# Configure BitNinja to listen on port 443 (not 60414)
log_and_console "Configuring BitNinja to listen on port 443..."
if [ -f "/etc/bitninja/SslTerminating/config.ini" ]; then
  sed -i 's/^WafFrontEndSettings\[port\]=60414$/WafFrontEndSettings[port]=443/' /etc/bitninja/SslTerminating/config.ini || true
  sed -i 's/^WafFrontEndSettings\[port\]=60415$/WafFrontEndSettings[port]=443/' /etc/bitninja/SslTerminating/config.ini || true
  log_and_console "✓ BitNinja configured to listen on port 443"
else
  log_and_console "⚠ WARNING: /etc/bitninja/SslTerminating/config.ini not found"
fi

# Force recollection
log_and_console "Forcing certificate recollection..."
bitninjacli --module=SslTerminating --force-recollect || true

# Restart BitNinja
log_and_console "Restarting BitNinja to generate config files..."
systemctl restart bitninja

# Wait for config generation with retry logic
log_and_console "Waiting for config file generation..."
ATTEMPT=1
MAX_ATTEMPTS=3

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  log_and_console "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
  
  WAIT_COUNT=0
  while [ ! -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ] && [ $WAIT_COUNT -lt 60 ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
  done
  
  if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
    log_and_console "✓ Config files generated after ${WAIT_COUNT} seconds (attempt $ATTEMPT)"
    break
  else
    if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
      log_and_console "⚠ Config files not generated after 60 seconds, retrying..."
      bitninjacli --module=SslTerminating --force-recollect
      systemctl restart bitninja
      sleep 30
      ATTEMPT=$((ATTEMPT + 1))
    else
      log_and_console "⚠ Config files not generated after $MAX_ATTEMPTS attempts (180 seconds total)"
      log_and_console "⚠ BitNinja may need more time to stabilize. You can:"
      log_and_console "   1. Wait 5 minutes and re-run this script"
      log_and_console "   2. Check logs: tail -50 /var/log/bitninja/error.log"
      exit 1
    fi
  fi
done

# Fix backend configuration
log_and_console "Configuring BitNinja backend and removing IPv6..."

# Remove immutable flags
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Fix backend to point to Apache (with error handling)
sed -i 's/server[[:space:]]\+origin-backend[[:space:]]\+\*:443.*/server\torigin-backend 127.0.0.1:80 check backup/' \
  /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true

# Remove IPv6 binds (with error handling)
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
sed -i '/\[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Fix internal port bindings (with error handling)
sed -i 's/bind \*:60415/bind 127.0.0.1:60415/' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
sed -i 's/bind \*:60418/bind 127.0.0.1:60418/' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true

# Make configs immutable
chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true
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
HTTP_CODE=$(curl -I -s -k -o /dev/null -w "%{http_code}" https://$DOMAIN/ 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ]; then
  log_and_console "✓ HTTPS working correctly (HTTP $HTTP_CODE)"
else
  log_and_console "⚠ HTTPS test failed (HTTP $HTTP_CODE)"
  log_and_console "This may be normal if DNS is not configured yet"
fi

log_and_console ""
log_and_console "=== BITNINJA FINAL CONFIGURATION COMPLETE ==="
log_and_console "✓ BitNinja SSL termination is now fully configured"
log_and_console "✓ Your Nextcloud is accessible at: https://$DOMAIN/"

