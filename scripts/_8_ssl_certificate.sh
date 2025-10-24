#!/bin/bash
# SSL Certificate Acquisition Script
# Obtains Let's Encrypt SSL certificate using certbot

source /root/system-setup/config.sh
log_and_console "=== SSL CERTIFICATE ACQUISITION ==="
log_and_console "Server IP: $SERVER_IP"
log_and_console "Domain: $DOMAIN"

# Check if DNS is configured correctly
log_and_console "Verifying DNS configuration..."

# Check IPv4 (A record)
RESOLVED_IP=$(dig +short "$DOMAIN" @8.8.8.8 A | tail -n1)

if [ -z "$RESOLVED_IP" ]; then
  log_and_console "⚠ WARNING: DNS not configured for $DOMAIN"
  log_and_console "Please configure DNS A record: $DOMAIN → $SERVER_IP"
  log_and_console "Skipping SSL certificate acquisition"
  log_and_console "After DNS is configured, run:"
  log_and_console "  /root/system-setup/scripts/_8_ssl_certificate.sh"
  exit 0
fi

if [ "$RESOLVED_IP" != "$SERVER_IP" ]; then
  log_and_console "⚠ WARNING: DNS mismatch!"
  log_and_console "  Domain $DOMAIN resolves to: $RESOLVED_IP"
  log_and_console "  Server IP is: $SERVER_IP"
  log_and_console "Please update DNS A record and wait for propagation"
  log_and_console "Skipping SSL certificate acquisition"
  exit 0
fi

log_and_console "✓ DNS A record correctly configured: $DOMAIN → $SERVER_IP"

# Check IPv6 (AAAA record) if IPv6 is enabled
if [ "$DISABLE_IPV6" != "true" ] && [ -n "$SERVER_IPV6" ]; then
  RESOLVED_IPV6=$(dig +short "$DOMAIN" @8.8.8.8 AAAA | tail -n1)
  
  if [ -z "$RESOLVED_IPV6" ]; then
    log_and_console "⚠ WARNING: IPv6 enabled but no AAAA record found for $DOMAIN"
    log_and_console "Consider adding DNS AAAA record: $DOMAIN → $SERVER_IPV6"
    log_and_console "Continuing with IPv4 only..."
  elif [ "$RESOLVED_IPV6" != "$SERVER_IPV6" ]; then
    log_and_console "⚠ WARNING: DNS AAAA record mismatch!"
    log_and_console "  Domain $DOMAIN resolves to: $RESOLVED_IPV6"
    log_and_console "  Server IPv6 is: $SERVER_IPV6"
    log_and_console "Consider updating DNS AAAA record"
    log_and_console "Continuing with IPv4..."
  else
    log_and_console "✓ DNS AAAA record correctly configured: $DOMAIN → $SERVER_IPV6"
  fi
fi

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  log_and_console "✓ SSL certificate already exists for $DOMAIN"
  exit 0
fi

# Obtain Let's Encrypt certificate
# Note: Apache is already configured to bind to 127.0.0.1:80 only, so certbot can bind to port 80
log_and_console "Requesting Let's Encrypt certificate for $DOMAIN..."
log_and_console "This may take 1-2 minutes..."

# Configure certbot binding based on IPv6 setting
if [ "$DISABLE_IPV6" = "true" ]; then
  log_and_console "IPv6 disabled - certbot will bind to IPv4 only ($SERVER_IP:80)"
  CERTBOT_HTTP_ADDRESS="--http-01-address $SERVER_IP"
else
  log_and_console "IPv6 enabled - certbot will bind to both IPv4 and IPv6 (0.0.0.0:80 and [::]:80)"
  CERTBOT_HTTP_ADDRESS=""
fi

certbot certonly --standalone \
  $CERTBOT_HTTP_ADDRESS \
  -d "$DOMAIN" \
  --email "$ADMIN_EMAIL" \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http-01

CERTBOT_EXIT_CODE=$?

# Check if certificate was obtained successfully
if [ $CERTBOT_EXIT_CODE -eq 0 ] && [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  log_and_console "✓ SSL certificate obtained successfully for $DOMAIN"
  log_and_console "Note: Certificate will be added to BitNinja in the next step"
  
  # Set up automatic renewal hooks
  log_and_console "Configuring automatic certificate renewal..."
  
  # Create renewal post-hook (restart BitNinja to pick up renewed certificate)
  # Note: Certificate paths are symlinks, so BitNinja just needs to reload
  mkdir -p /etc/letsencrypt/renewal-hooks/post
  cat > /etc/letsencrypt/renewal-hooks/post/update-bitninja.sh <<'EOFPOST'
#!/bin/bash
# Restart BitNinja to pick up renewed certificate
# Certificate paths are symlinks that certbot updates, so just restart
systemctl restart bitninja
EOFPOST
  chmod +x /etc/letsencrypt/renewal-hooks/post/update-bitninja.sh
  
  log_and_console "✓ Automatic renewal configured (certbot timer renews every 60 days)"
  
else
  log_and_console "✗ ERROR: Failed to obtain SSL certificate"
  log_and_console "Certbot exit code: $CERTBOT_EXIT_CODE"
  log_and_console "Please check:"
  log_and_console "  1. DNS is correctly configured: $DOMAIN → $SERVER_IP"
  log_and_console "  2. Port 80 is accessible from the internet"
  log_and_console "  3. Firewall (UFW) allows port 80"
  log_and_console ""
  log_and_console "To retry manually:"
  log_and_console "  /root/system-setup/scripts/_8_ssl_certificate.sh"
  exit 1
fi

