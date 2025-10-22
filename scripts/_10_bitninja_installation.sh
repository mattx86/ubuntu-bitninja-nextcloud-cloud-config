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
  
  # Note: BitNinja modules are enabled by default unless listed in disabledModules
  # We only need to configure the disabledModules array in config.php
  # CLI --enable/--disable commands are runtime-only and don't persist
  log_and_console "BitNinja module configuration will be set via config.php..."
  
  # Configure automatic SSL certificate collection
  log_and_console "Configuring automatic SSL certificate management..."
  
  # Check if SSL certificates exist
  if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_and_console "SSL certificates found for $DOMAIN, configuring BitNinja to use them..."
    
    # Restart entire BitNinja service to ensure ConfigParser scans Apache and picks up SSL
    log_and_console "Restarting BitNinja service to apply SSL configuration..."
    systemctl restart bitninja
    
    # Wait for BitNinja to fully restart and scan Apache configuration
    log_and_console "Waiting for BitNinja to restart and scan Apache config (15 seconds)..."
    sleep 15
    
    # Verify SSL is enabled
    if bitninjacli --module=WAFManager --status 2>/dev/null | grep -q '"isSsl": true'; then
      log_and_console "✓ SSL successfully enabled on WAFManager (port 60414 is now HTTPS)"
    else
      log_and_console "⚠ WARNING: SSL may not be enabled on WAFManager"
      log_and_console "Diagnostic commands:"
      log_and_console "  bitninjacli --module=WAFManager --status"
      log_and_console "  cat /var/lib/bitninja/ConfigParser/getCerts-report.json"
      log_and_console "  cat /opt/bitninja-ssl-termination/etc/haproxy/cert-list.lst"
    fi
  else
    log_and_console "⚠ No SSL certificates found yet - BitNinja will use HTTP mode"
    log_and_console "After obtaining SSL certificates, run:"
    log_and_console "  systemctl restart bitninja"
  fi
  
  # Disable unused modules via config.php
  log_and_console "Configuring disabled modules in /etc/bitninja/config.php..."
  if [ -f /etc/bitninja/config.php ]; then
    # Backup original config
    cp /etc/bitninja/config.php /etc/bitninja/config.php.backup
    
    # Create new config with our disabled modules (PHP array format)
    cat > /etc/bitninja/config.php <<'EOFCONFIG'
<?php
/*
 * BitNinja user configuration file.
 * Managed by ubuntu-bitninja-nextcloud-cloud-config
 */
return array(
    'general' => array(
        'api_url' => 'https://api.bitninja.io',
        'api2_url' => 'https://api.bitninja.io',
        'disabledModules' => array(
            // Core modules (DO NOT DISABLE - required for functionality)
            // 'System',
            // 'DataProvider',
            // 'ConfigParser',
            
            // Firewall management (DISABLED - UFW manages firewall)
            'IpFilter',
            
            // Modules we're using (DO NOT DISABLE)
            // 'SslTerminating',
            // 'WAFManager',
            // 'MalwareDetection',
            // 'DosDetection',
            // 'SenseLog',
            // 'DefenseRobot',
            
            // Unused modules (DISABLED)
            'AntiFlood',
            'AuditManager',
            'CaptchaFtp',
            'CaptchaHttp',
            'CaptchaSmtp',
            'MalwareScanner',
            'OutboundHoneypot',
            'Patcher',
            'PortHoneypot',
            'ProxyFilter',
            'SandboxScanner',
            'SenseWebHoneypot',
            'Shogun',
            'SiteProtection',
            'SpamDetection',
            'SqlScanner',
            'TalkBack',
            'WAF3',
            'ProcessAnalysis',
        )
    ),
);
EOFCONFIG
    
    chmod 600 /etc/bitninja/config.php
    chown root:root /etc/bitninja/config.php
    log_and_console "✓ BitNinja /etc/bitninja/config.php updated (disabled modules)"
  else
    log_and_console "⚠ WARNING: /etc/bitninja/config.php not found"
  fi
  
  # Restart BitNinja to apply module configuration and ensure SslTerminating config is created
  log_and_console "Restarting BitNinja to apply module configuration..."
  systemctl restart bitninja
  sleep 10
  
  # Configure localhost binding in SslTerminating config (INI format)
  # This file is created by BitNinja after the first start, so we configure it after restart
  log_and_console "Configuring localhost-only binding in /etc/bitninja/SslTerminating/config.ini..."
  
  # Wait for config file to be created (up to 30 seconds)
  WAIT_COUNT=0
  while [ ! -f /etc/bitninja/SslTerminating/config.ini ] && [ $WAIT_COUNT -lt 30 ]; do
    sleep 1
    WAIT_COUNT=$((WAIT_COUNT + 1))
  done
  
  if [ -f /etc/bitninja/SslTerminating/config.ini ]; then
    # Backup original config
    cp /etc/bitninja/SslTerminating/config.ini /etc/bitninja/SslTerminating/config.ini.backup
    
    # Change WafFrontEndSettings[iface] from '[::]' to '127.0.0.1'
    sed -i "s/^WafFrontEndSettings\[iface\]=.*/WafFrontEndSettings[iface]='127.0.0.1'/" /etc/bitninja/SslTerminating/config.ini
    log_and_console "✓ Updated WafFrontEndSettings[iface] to '127.0.0.1'"
    
    # Change CaptchaFrontEndSettings[iface] from '[::]' to '127.0.0.1'
    sed -i "s/^CaptchaFrontEndSettings\[iface\]=.*/CaptchaFrontEndSettings[iface]='127.0.0.1'/" /etc/bitninja/SslTerminating/config.ini
    log_and_console "✓ Updated CaptchaFrontEndSettings[iface] to '127.0.0.1'"
    
    log_and_console "✓ BitNinja SslTerminating configured for localhost-only binding (127.0.0.1)"
    
    # Restart BitNinja again to apply localhost binding
    log_and_console "Restarting BitNinja to apply localhost binding..."
    systemctl restart bitninja
    sleep 5
  else
    log_and_console "⚠ WARNING: /etc/bitninja/SslTerminating/config.ini not found after 30 seconds"
    log_and_console "BitNinja may still be initializing. Manual configuration required:"
    log_and_console "  1. Wait for BitNinja to fully start"
    log_and_console "  2. Edit /etc/bitninja/SslTerminating/config.ini"
    log_and_console "  3. Change WafFrontEndSettings[iface]='[::]' to '127.0.0.1'"
    log_and_console "  4. Change CaptchaFrontEndSettings[iface]='[::]' to '127.0.0.1'"
    log_and_console "  5. Run: systemctl restart bitninja"
  fi
  
  # Sync configuration to cloud
  bitninjacli --syncconfigs 2>/dev/null && log_and_console "✓ Config synced to BitNinja cloud" || log_and_console "Config sync skipped"
  
  # Configure manual DNAT rules via UFW (BitNinja firewall management disabled)
  log_and_console "Configuring manual DNAT rules for BitNinja WAF..."
  
  # Add DNAT rule to redirect port 443 to BitNinja SSL Terminating (port 60414)
  # This is added to UFW's before.rules to ensure it persists across reboots
  # We redirect external port 443 to localhost:60414 for maximum security
  # BitNinja only listens on localhost, not accessible directly from internet
  if ! grep -q "BitNinja WAF DNAT" /etc/ufw/before.rules; then
    log_and_console "Adding DNAT rule: 443 → 127.0.0.1:60414"
    
    # Add nat table section if it doesn't exist
    if ! grep -q "^\*nat" /etc/ufw/before.rules; then
      # Add nat table at the beginning of the file (before *filter table)
      # Use :PREROUTING - [0:0] to FLUSH the chain before adding rules (prevents duplicates)
      sed -i '1i\
# NAT table for DNAT rules\
*nat\
:PREROUTING - [0:0]\
:POSTROUTING ACCEPT [0:0]\
\
# BitNinja WAF DNAT - Redirect HTTPS traffic to BitNinja SSL Terminating (localhost)\
-A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:60414\
\
# Commit nat table\
COMMIT\
' /etc/ufw/before.rules
    else
      # nat table exists, update PREROUTING policy to flush and add the DNAT rule
      # First, ensure PREROUTING uses - policy to flush
      sed -i 's/^:PREROUTING ACCEPT \[0:0\]$/:PREROUTING - [0:0]/' /etc/ufw/before.rules
      
      # Then add the DNAT rule if not already present
      if ! grep -q "60414" /etc/ufw/before.rules; then
        sed -i '/^\*nat/,/^COMMIT$/ {
          /^COMMIT$/ i\
# BitNinja WAF DNAT - Redirect HTTPS traffic to BitNinja SSL Terminating (localhost)\
-A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:60414
        }' /etc/ufw/before.rules
      fi
    fi
    
    # Reload UFW to apply changes
    ufw reload
    log_and_console "✓ DNAT rule added and UFW reloaded"
  else
    log_and_console "✓ DNAT rule already exists"
  fi
  
  # Verify DNAT rules
  log_and_console "Verifying DNAT rules..."
  sleep 2
  
  if iptables -t nat -L PREROUTING -n -v 2>/dev/null | grep -q "60414"; then
    log_and_console "✓ DNAT rule active: port 443 → 127.0.0.1:60414"
    
    # Count DNAT rules (should be exactly 1 due to flush policy)
    DNAT_COUNT=$(iptables -t nat -L PREROUTING -n -v 2>/dev/null | grep -c "60414" || echo "0")
    if [ "$DNAT_COUNT" -gt 1 ]; then
      log_and_console "⚠ WARNING: Multiple DNAT rules detected ($DNAT_COUNT instances)"
      log_and_console "This should not happen with :PREROUTING - policy. Check /etc/ufw/before.rules"
    fi
  else
    log_and_console "⚠ WARNING: DNAT rule not detected in iptables"
    log_and_console "Check manually: iptables -t nat -L PREROUTING -n -v"
  fi
  
  # Verify WAF2 status
  log_and_console "Verifying WAF2 configuration..."
  sleep 2
  if bitninjacli --module=WAF --status 2>/dev/null | grep -q "active"; then
    log_and_console "✓ WAF2 is active"
  else
    log_and_console "⚠ WARNING: WAF2 status check inconclusive - manual verification recommended"
  fi
  
  # Display comprehensive status for troubleshooting
  log_and_console ""
  log_and_console "=== BitNinja Configuration Summary ==="
  log_and_console "Listening Ports (should all be 127.0.0.1):"
  ss -tlnp | grep -E ':(443|60414|60415)' | tee -a "$LOG_FILE"
  
  # Verify localhost-only binding
  if ss -tlnp | grep -E ':(60414|60415)' | grep -q '0.0.0.0\|:::'; then
    log_and_console "⚠ WARNING: BitNinja is listening on all interfaces (0.0.0.0 or :::)"
    log_and_console "Expected: 127.0.0.1 only. Check /etc/bitninja/SslTerminating/config.ini"
    log_and_console "Verify: grep 'FrontEndSettings\[iface\]' /etc/bitninja/SslTerminating/config.ini"
  else
    log_and_console "✓ BitNinja correctly bound to localhost only"
  fi
  
  log_and_console ""
  log_and_console "Active DNAT Rules:"
  iptables -t nat -L PREROUTING -n -v --line-numbers | grep -E '(Chain|60414)' | tee -a "$LOG_FILE"
  
  log_and_console ""
  log_and_console "UFW Status:"
  ufw status | grep -E '(Status:|443)' | tee -a "$LOG_FILE"
  
  log_and_console ""
  log_and_console "SSL Certificates:"
  if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    log_and_console "✓ Certificate exists for $DOMAIN"
    ls -la "/etc/letsencrypt/live/$DOMAIN/" | tee -a "$LOG_FILE"
  else
    log_and_console "⚠ No certificate found for $DOMAIN"
    log_and_console "Run: sudo /root/system-setup/scripts/_8_ssl_certificate.sh"
  fi
  
  log_and_console ""
  log_and_console "WAFManager Status:"
  bitninjacli --module=WAFManager --status 2>/dev/null | grep -E '(isSsl|enabled|port)' | tee -a "$LOG_FILE" || log_and_console "WAFManager status unavailable"
  
  log_and_console ""
  log_and_console "SslTerminating Status:"
  bitninjacli --module=SslTerminating --status 2>/dev/null | grep -E '(enabled|certificate)' | tee -a "$LOG_FILE" || log_and_console "SslTerminating status unavailable"
  
  log_and_console ""
  log_and_console "=== Next Steps ==="
  log_and_console "1. Verify DNS points to this server: dig $DOMAIN"
  log_and_console "2. Test from external machine: curl -k https://$DOMAIN/"
  log_and_console "3. Check logs: tail -f /var/log/bitninja/error.log"
  log_and_console "4. Check Apache: tail -f /var/log/apache2/nextcloud-error.log"
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
