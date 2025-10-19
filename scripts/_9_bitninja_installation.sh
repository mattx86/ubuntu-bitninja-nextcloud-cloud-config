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
  
  # Configure DNAT rules for WAF2 via UFW
  log_and_console "Configuring DNAT rules for WAF2..."
  
  # Get server's primary IP address
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  # Add DNAT rule to UFW's before.rules for persistence
  log_and_console "Adding DNAT rule: port 443 → 60414 (WAF2 SSL Terminating)"
  log_and_console "Note: Port 80 left open for certbot standalone (automatic SSL acquisition)"
  
  # Backup UFW before.rules
  cp /etc/ufw/before.rules /etc/ufw/before.rules.backup
  
  # Check if DNAT rules already exist
  if ! grep -q "BN_WAF_REDIR" /etc/ufw/before.rules; then
    # Add DNAT rules after the *nat table section
    sed -i '/^\*nat$/a \
:BN_WAF_REDIR - [0:0]\n\
# BitNinja WAF2 DNAT rule for HTTPS\n\
# Port 443 → SSL Terminating port 60414 (decrypts HTTPS and forwards to WAF2)\n\
# Port 80 is left open for certbot standalone (no DNAT needed)\n\
-A PREROUTING -p tcp -m tcp --dport 443 -j BN_WAF_REDIR\n\
-A BN_WAF_REDIR -d '"$SERVER_IP"'/32 -p tcp -m tcp --dport 443 -j DNAT --to-destination '"127.0.0.1"':60414' /etc/ufw/before.rules
    
    log_and_console "✓ DNAT rules added to /etc/ufw/before.rules"
    
    # Reload UFW to apply changes
    ufw reload
    log_and_console "✓ UFW reloaded with DNAT rules"
  else
    log_and_console "✓ DNAT rules already exist in UFW configuration"
  fi
  
  # Verify WAF2 status
  log_and_console "Verifying WAF2 configuration..."
  sleep 2
  if bitninjacli --module=WAF --status 2>/dev/null | grep -q "active"; then
    log_and_console "✓ WAF2 is active and handling port 443 → 60415 → Apache"
  else
    log_and_console "⚠ WARNING: WAF2 status check inconclusive - manual verification recommended"
  fi
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
