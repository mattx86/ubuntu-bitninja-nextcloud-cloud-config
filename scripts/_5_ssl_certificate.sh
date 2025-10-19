#!/bin/bash
# SSL Certificate Acquisition Script
# Obtains Let's Encrypt SSL certificate using certbot

source /root/system-setup/config.sh
log_and_console "=== SSL CERTIFICATE ACQUISITION ==="

# Get server's primary IP address
SERVER_IP=$(hostname -I | awk '{print $1}')
log_and_console "Server IP: $SERVER_IP"
log_and_console "Domain: $DOMAIN"

# Check if DNS is configured correctly
log_and_console "Verifying DNS configuration..."
RESOLVED_IP=$(dig +short "$DOMAIN" @8.8.8.8 | tail -n1)

if [ -z "$RESOLVED_IP" ]; then
  log_and_console "⚠ WARNING: DNS not configured for $DOMAIN"
  log_and_console "Please configure DNS A record: $DOMAIN → $SERVER_IP"
  log_and_console "Skipping SSL certificate acquisition"
  log_and_console "After DNS is configured, run:"
  log_and_console "  /root/system-setup/scripts/_5_ssl_certificate.sh"
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

log_and_console "✓ DNS correctly configured: $DOMAIN → $SERVER_IP"

# Check if certificate already exists
if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  log_and_console "✓ SSL certificate already exists for $DOMAIN"
  log_and_console "Forcing BitNinja to recollect certificate..."
  bitninjacli --module=SslTerminating --force-recollect
  bitninjacli --module=SslTerminating --restart
  log_and_console "✓ BitNinja SSL Terminating updated"
  exit 0
fi

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
  log_and_console "Installing certbot..."
  apt-get install -y certbot || { log_and_console "ERROR: Failed to install certbot"; exit 1; }
  log_and_console "✓ certbot installed"
fi

# Stop Apache2 to free port 80 for certbot standalone
log_and_console "Stopping Apache2 to free port 80 for certbot..."
systemctl stop apache2 || log_and_console "⚠ Apache2 not running or failed to stop"

# Obtain Let's Encrypt certificate
log_and_console "Requesting Let's Encrypt certificate for $DOMAIN..."
log_and_console "This may take 1-2 minutes..."

certbot certonly --standalone \
  --http-01-address "$SERVER_IP" \
  -d "$DOMAIN" \
  --email "$ADMIN_EMAIL" \
  --agree-tos \
  --non-interactive \
  --preferred-challenges http-01

CERTBOT_EXIT_CODE=$?

# Start Apache2 again
log_and_console "Starting Apache2..."
systemctl start apache2 || log_and_console "⚠ WARNING: Failed to start Apache2"

# Check if certificate was obtained successfully
if [ $CERTBOT_EXIT_CODE -eq 0 ] && [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  log_and_console "✓ SSL certificate obtained successfully for $DOMAIN"
  
  # Configure BitNinja to use the certificate
  log_and_console "Configuring BitNinja SSL Terminating to use new certificate..."
  bitninjacli --module=SslTerminating --force-recollect
  bitninjacli --module=SslTerminating --restart
  
  log_and_console "✓ BitNinja SSL Terminating configured with Let's Encrypt certificate"
  log_and_console "✓ HTTPS is now active: https://$DOMAIN"
  
  # Set up automatic renewal hooks
  log_and_console "Configuring automatic certificate renewal..."
  
  # Create renewal post-hook (update BitNinja with renewed certificate)
  mkdir -p /etc/letsencrypt/renewal-hooks/post
  cat > /etc/letsencrypt/renewal-hooks/post/update-bitninja.sh <<'EOFPOST'
#!/bin/bash
# Update BitNinja with renewed certificate
bitninjacli --module=SslTerminating --force-recollect
bitninjacli --module=SslTerminating --restart
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
  log_and_console "  /root/system-setup/scripts/_5_ssl_certificate.sh"
  exit 1
fi

