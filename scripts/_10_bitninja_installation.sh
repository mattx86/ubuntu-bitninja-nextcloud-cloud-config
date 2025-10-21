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
    
    # Create new config with our disabled modules
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
    log_and_console "✓ BitNinja config.php updated with disabled modules"
    
    # Restart BitNinja to apply config changes
    log_and_console "Restarting BitNinja to apply module configuration..."
    systemctl restart bitninja
    sleep 5
    
    # Sync configuration to cloud
    bitninjacli --syncconfigs 2>/dev/null && log_and_console "✓ Config synced to BitNinja cloud" || log_and_console "Config sync skipped"
  else
    log_and_console "⚠ WARNING: /etc/bitninja/config.php not found"
  fi
  
  # Configure manual DNAT rules via UFW (BitNinja firewall management disabled)
  log_and_console "Configuring manual DNAT rules for BitNinja WAF..."
  
  # Add DNAT rule to redirect port 443 to BitNinja SSL Terminating (port 60414)
  # This is added to UFW's before.rules to ensure it persists across reboots
  if ! grep -q "BitNinja WAF DNAT" /etc/ufw/before.rules; then
    log_and_console "Adding DNAT rule: 443 → 127.0.0.1:60414"
    
    # Add nat table section if it doesn't exist
    if ! grep -q "^\*nat" /etc/ufw/before.rules; then
      # Add nat table at the beginning of the file (before *filter table)
      sed -i '1i\
# NAT table for DNAT rules\
*nat\
:PREROUTING ACCEPT [0:0]\
:POSTROUTING ACCEPT [0:0]\
\
# BitNinja WAF DNAT - Redirect HTTPS traffic to BitNinja SSL Terminating\
-A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:60414\
\
# Commit nat table\
COMMIT\
' /etc/ufw/before.rules
    else
      # nat table exists, just add the DNAT rule before its COMMIT
      sed -i '/^\*nat/,/^COMMIT$/ {
        /^COMMIT$/ i\
# BitNinja WAF DNAT - Redirect HTTPS traffic to BitNinja SSL Terminating\
-A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:60414
      }' /etc/ufw/before.rules
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
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
