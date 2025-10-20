#!/bin/bash
# BitNinja Installation Script
# Installs and configures BitNinja security features

source /root/system-setup/config.sh
log_and_console "=== BITNINJA INSTALLATION ==="
log_and_console "Downloading BitNinja installer..."

# Download installer with retry logic
curl --retry 3 --max-time 60 https://get.bitninja.io/install.sh -o "$DOWNLOADS_DIR/bitninja-install.sh" || { log_and_console "ERROR: Failed to download BitNinja installer"; exit 1; }
chmod 600 "$DOWNLOADS_DIR/bitninja-install.sh"

log_and_console "Installing BitNinja..."
# Set non-interactive mode and disable needrestart prompts
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
/bin/bash "$DOWNLOADS_DIR/bitninja-install.sh" --license_key="$BITNINJA_LICENSE" || { log_and_console "ERROR: BitNinja installation failed (check license key)"; exit 1; }

if command -v bitninjacli &> /dev/null && systemctl is-active --quiet bitninja; then
  log_and_console "Configuring BitNinja security features..."
  
  # Enable core security modules
  bitninjacli --module=SslTerminating --enable 2>/dev/null && log_and_console "✓ SSL Terminating enabled" || log_and_console "SSL Terminating already enabled"
  bitninjacli --module=WAFManager --enable 2>/dev/null && log_and_console "✓ WAF 2.0 enabled" || log_and_console "WAF 2.0 already enabled"
  bitninjacli --module=MalwareScanner --enable 2>/dev/null && log_and_console "✓ Malware Scanner enabled" || log_and_console "Malware Scanner already enabled"
  bitninjacli --module=IpReputation --enable 2>/dev/null && log_and_console "✓ IP Reputation enabled" || log_and_console "IP Reputation already enabled"
  bitninjacli --module=DosDetection --enable 2>/dev/null && log_and_console "✓ DoS Detection enabled" || log_and_console "DoS Detection already enabled"
  bitninjacli --module=OutboundWaf --enable 2>/dev/null && log_and_console "✓ Outbound WAF enabled" || log_and_console "Outbound WAF already enabled"
  bitninjacli --module=SenseLog --enable 2>/dev/null && log_and_console "✓ SenseLog enabled" || log_and_console "SenseLog already enabled"
  bitninjacli --module=DefenseRobot --enable 2>/dev/null && log_and_console "✓ Defense Robot enabled" || log_and_console "Defense Robot already enabled"
  
  # Configure automatic SSL certificate collection
  log_and_console "Configuring automatic SSL certificate management..."
  
  # Check if SSL certificates exist
  if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_and_console "SSL certificates found for $DOMAIN, configuring BitNinja to use them..."
    
    # Force ConfigParser to scan Apache configuration for SSL certificates
    log_and_console "Forcing ConfigParser to scan Apache configuration..."
    bitninjacli --module=SslTerminating --force-recollect 2>/dev/null && \
      log_and_console "✓ ConfigParser scanned Apache configuration" || \
      log_and_console "⚠ ConfigParser scan may have failed"
    
    # Restart entire BitNinja service to ensure all modules pick up SSL
    log_and_console "Restarting BitNinja service to apply SSL configuration..."
    systemctl restart bitninja
    
    # Wait for BitNinja to fully restart
    log_and_console "Waiting for BitNinja to restart (15 seconds)..."
    sleep 15
    
    # Verify SSL is enabled
    if bitninjacli --module=WAFManager --status 2>/dev/null | grep -q '"isSsl": true'; then
      log_and_console "✓ SSL successfully enabled on WAFManager (port 60415 is now HTTPS)"
    else
      log_and_console "⚠ WARNING: SSL may not be enabled on WAFManager"
      log_and_console "Diagnostic commands:"
      log_and_console "  bitninjacli --module=WAFManager --status"
      log_and_console "  cat /var/lib/bitninja/ConfigParser/getCerts-report.json"
      log_and_console "  cat /opt/bitninja-ssl-termination/etc/haproxy/cert-list.lst"
    fi
  else
    log_and_console "⚠ No SSL certificates found yet - BitNinja will use HTTP mode on port 60415"
    log_and_console "After obtaining SSL certificates, run:"
    log_and_console "  bitninjacli --module=SslTerminating --force-recollect"
    log_and_console "  systemctl restart bitninja"
  fi
  
  # Configure BitNinja to create DNAT rules automatically
  log_and_console "Configuring BitNinja WAFManager to create DNAT rules..."
  
  # Get server's primary IP address
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  # Enable WAFManager on the server's IP (this triggers automatic DNAT rule creation)
  log_and_console "Enabling WAFManager on IP: $SERVER_IP"
  bitninjacli --module=WAFManager --enable-on-ip="$SERVER_IP" 2>/dev/null && \
    log_and_console "✓ WAFManager enabled on $SERVER_IP" || \
    log_and_console "⚠ WAFManager enable may have failed"
  

  # Verify DNAT rules were created by BitNinja
  log_and_console "Verifying BitNinja DNAT rules..."
  if iptables -t nat -L PREROUTING -n -v 2>/dev/null | grep -q "60414"; then
    log_and_console "✓ BitNinja DNAT rules created: port 443 → 60414"
  else
    log_and_console "⚠ WARNING: BitNinja DNAT rules not detected"
    log_and_console "Check manually: iptables -t nat -L PREROUTING -n -v | grep BN_WAF"
  fi
  
  # Verify WAF2 status
  log_and_console "Verifying WAF2 configuration..."
  sleep 2
  if bitninjacli --module=WAF --status 2>/dev/null | grep -q "active"; then
    log_and_console "✓ WAF2 is active"
  else
    log_and_console "⚠ WARNING: WAF2 status check inconclusive - manual verification recommended"
  fi
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
