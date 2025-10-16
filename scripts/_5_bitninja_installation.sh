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
  bitninjacli --module=WAF3 --enable 2>/dev/null && log_and_console "✓ WAF Pro enabled" || log_and_console "WAF Pro already enabled"
  
  # Configure WAF3 for automatic SSL (Let's Encrypt)
  log_and_console "Configuring WAF3 for automatic SSL certificate provisioning..."
  
  # Wait for WAF3 config file to be created
  sleep 1
  
  # Enable automatic SSL in WAF3 config
  if [ -f /etc/bitninja/WAF3/config.ini ]; then
    # Backup config
    cp /etc/bitninja/WAF3/config.ini /etc/bitninja/WAF3/config.ini.backup
    
    # Enable auto_ssl
    sed -i 's/^auto_ssl=0/auto_ssl=1/' /etc/bitninja/WAF3/config.ini
    log_and_console "✓ WAF3 auto_ssl enabled in config.ini"
    
    # Restart WAF3 to apply configuration
    systemctl restart bitninja-waf3 2>/dev/null && log_and_console "✓ WAF3 restarted with automatic SSL" || log_and_console "⚠ Could not restart bitninja-waf3 (will start automatically)"
  else
    log_and_console "⚠ WARNING: /etc/bitninja/WAF3/config.ini not found yet (may be created after first start)"
  fi
  bitninjacli --module=MalwareScanner --enable 2>/dev/null && log_and_console "✓ Malware Scanner enabled" || log_and_console "Malware Scanner already enabled"
  bitninjacli --module=IpReputation --enable 2>/dev/null && log_and_console "✓ IP Reputation enabled" || log_and_console "IP Reputation already enabled"
  bitninjacli --module=DosDetection --enable 2>/dev/null && log_and_console "✓ DoS Detection enabled" || log_and_console "DoS Detection already enabled"
  bitninjacli --module=OutboundWaf --enable 2>/dev/null && log_and_console "✓ Outbound WAF enabled" || log_and_console "Outbound WAF already enabled"
  bitninjacli --module=SenseLog --enable 2>/dev/null && log_and_console "✓ SenseLog enabled" || log_and_console "SenseLog already enabled"
  bitninjacli --module=DefenseRobot --enable 2>/dev/null && log_and_console "✓ Defense Robot enabled" || log_and_console "Defense Robot already enabled"
  
  # Configure DNAT rules for WAF Pro via UFW
  log_and_console "Configuring DNAT rules for WAF Pro..."
  
  # Get server's primary IP address
  SERVER_IP=$(hostname -I | awk '{print $1}')
  
  # Add DNAT rule to UFW's before.rules for persistence
  log_and_console "Adding DNAT rule to UFW configuration: port 443 → 60414 (WAF3 HTTPS)"
  
  # Backup UFW before.rules
  cp /etc/ufw/before.rules /etc/ufw/before.rules.backup
  
  # Check if DNAT rules already exist
  if ! grep -q "BN_WAF_REDIR" /etc/ufw/before.rules; then
    # Add DNAT rules after the *nat table section
    sed -i '/^\*nat$/a \
:BN_WAF_REDIR - [0:0]\n\
# BitNinja WAF Pro DNAT rule - redirect port 443 to WAF3 SSL Terminating port\n\
-A PREROUTING -p tcp -m tcp --dport 443 -j BN_WAF_REDIR\n\
-A BN_WAF_REDIR -d '"$SERVER_IP"'/32 -p tcp -m tcp --dport 443 -j DNAT --to-destination '"127.0.0.1"':60414' /etc/ufw/before.rules
    
    log_and_console "✓ DNAT rules added to /etc/ufw/before.rules"
    
    # Reload UFW to apply changes
    ufw reload
    log_and_console "✓ UFW reloaded with DNAT rules"
  else
    log_and_console "✓ DNAT rules already exist in UFW configuration"
  fi
  
  # Verify WAF Pro port redirections are active
  log_and_console "Verifying WAF Pro port redirections..."
  sleep 3  # Give WAF Pro time to set up redirections
  if bitninjacli --module=WAF3 --status 2>/dev/null | grep -q "active"; then
    log_and_console "✓ WAF Pro is active and handling port 443 → 60414 → Apache"
  else
    log_and_console "⚠ WARNING: WAF Pro status check inconclusive - manual verification recommended"
  fi
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
