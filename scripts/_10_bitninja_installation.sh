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
  
  # Enable mandatory/required modules
  log_and_console "Enabling required and core security modules..."
  bitninjacli --module=System --enable 2>/dev/null && log_and_console "✓ System enabled (mandatory)" || log_and_console "System already enabled"
  bitninjacli --module=ConfigParser --enable 2>/dev/null && log_and_console "✓ ConfigParser enabled (required for SSL cert detection)" || log_and_console "ConfigParser already enabled"
  bitninjacli --module=DataProvider --enable 2>/dev/null && log_and_console "✓ DataProvider enabled (required)" || log_and_console "DataProvider already enabled"
  bitninjacli --module=SslTerminating --enable 2>/dev/null && log_and_console "✓ SSL Terminating enabled" || log_and_console "SSL Terminating already enabled"
  bitninjacli --module=WAFManager --enable 2>/dev/null && log_and_console "✓ WAF 2.0 enabled" || log_and_console "WAF 2.0 already enabled"
  
  # Enable additional security modules
  log_and_console "Enabling additional security modules..."
  bitninjacli --module=MalwareDetection --enable 2>/dev/null && log_and_console "✓ Malware Detection enabled" || log_and_console "Malware Detection already enabled"
  bitninjacli --module=DosDetection --enable 2>/dev/null && log_and_console "✓ DoS Detection enabled" || log_and_console "DoS Detection already enabled"
  bitninjacli --module=SenseLog --enable 2>/dev/null && log_and_console "✓ SenseLog enabled" || log_and_console "SenseLog already enabled"
  bitninjacli --module=DefenseRobot --enable 2>/dev/null && log_and_console "✓ Defense Robot enabled" || log_and_console "Defense Robot already enabled"
  
  # Disable all unused modules to prevent unwanted behavior
  log_and_console "Disabling unused modules..."
  bitninjacli --module=IpFilter --disable 2>/dev/null && log_and_console "✓ IpFilter disabled (no firewall management)" || log_and_console "IpFilter already disabled"
  bitninjacli --module=AntiFlood --disable 2>/dev/null && log_and_console "✓ AntiFlood disabled" || log_and_console "AntiFlood already disabled"
  bitninjacli --module=AuditManager --disable 2>/dev/null && log_and_console "✓ AuditManager disabled" || log_and_console "AuditManager already disabled"
  bitninjacli --module=CaptchaFtp --disable 2>/dev/null && log_and_console "✓ CaptchaFtp disabled" || log_and_console "CaptchaFtp already disabled"
  bitninjacli --module=CaptchaHttp --disable 2>/dev/null && log_and_console "✓ CaptchaHttp disabled" || log_and_console "CaptchaHttp already disabled"
  bitninjacli --module=CaptchaSmtp --disable 2>/dev/null && log_and_console "✓ CaptchaSmtp disabled" || log_and_console "CaptchaSmtp already disabled"
  bitninjacli --module=MalwareScanner --disable 2>/dev/null && log_and_console "✓ MalwareScanner disabled (using MalwareDetection)" || log_and_console "MalwareScanner already disabled"
  bitninjacli --module=OutboundHoneypot --disable 2>/dev/null && log_and_console "✓ OutboundHoneypot disabled" || log_and_console "OutboundHoneypot already disabled"
  bitninjacli --module=Patcher --disable 2>/dev/null && log_and_console "✓ Patcher disabled" || log_and_console "Patcher already disabled"
  bitninjacli --module=PortHoneypot --disable 2>/dev/null && log_and_console "✓ PortHoneypot disabled" || log_and_console "PortHoneypot already disabled"
  bitninjacli --module=ProxyFilter --disable 2>/dev/null && log_and_console "✓ ProxyFilter disabled" || log_and_console "ProxyFilter already disabled"
  bitninjacli --module=SandboxScanner --disable 2>/dev/null && log_and_console "✓ SandboxScanner disabled" || log_and_console "SandboxScanner already disabled"
  bitninjacli --module=SenseWebHoneypot --disable 2>/dev/null && log_and_console "✓ SenseWebHoneypot disabled" || log_and_console "SenseWebHoneypot already disabled"
  bitninjacli --module=Shogun --disable 2>/dev/null && log_and_console "✓ Shogun disabled" || log_and_console "Shogun already disabled"
  bitninjacli --module=SiteProtection --disable 2>/dev/null && log_and_console "✓ SiteProtection disabled" || log_and_console "SiteProtection already disabled"
  bitninjacli --module=SpamDetection --disable 2>/dev/null && log_and_console "✓ SpamDetection disabled" || log_and_console "SpamDetection already disabled"
  bitninjacli --module=SqlScanner --disable 2>/dev/null && log_and_console "✓ SqlScanner disabled" || log_and_console "SqlScanner already disabled"
  bitninjacli --module=WAF3 --disable 2>/dev/null && log_and_console "✓ WAF3 disabled (using WAFManager)" || log_and_console "WAF3 already disabled"
  bitninjacli --module=ProcessAnalysis --disable 2>/dev/null && log_and_console "✓ ProcessAnalysis disabled" || log_and_console "ProcessAnalysis already disabled"
  
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
  
  # Configure manual DNAT rules via UFW (BitNinja firewall management disabled)
  log_and_console "Configuring manual DNAT rules for BitNinja WAF..."
  
  # Add DNAT rule to redirect port 443 to BitNinja SSL Terminating (port 60414)
  # This is added to UFW's before.rules to ensure it persists across reboots
  if ! grep -q "BitNinja WAF DNAT" /etc/ufw/before.rules; then
    log_and_console "Adding DNAT rule: 443 → 127.0.0.1:60414"
    
    # Insert DNAT rules before the COMMIT line in the nat table
    sed -i '/^COMMIT$/i \
# BitNinja WAF DNAT - Redirect HTTPS traffic to BitNinja SSL Terminating\
-A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 127.0.0.1:60414' /etc/ufw/before.rules
    
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
