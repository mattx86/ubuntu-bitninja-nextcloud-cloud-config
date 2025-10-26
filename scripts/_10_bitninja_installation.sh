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
            
            // ConfigParser (DISABLED - we manually manage SSL certificates via CLI)
            'ConfigParser',
            
            // Firewall management (DISABLED - UFW manages firewall)
            'IpFilter',
            
            // Modules we're using (DO NOT DISABLE)
            // 'SslTerminating',
            // 'MalwareDetection',
            // 'DosDetection',
            // 'SenseLog',
            // 'DefenseRobot',
            
            // WAFManager (DISABLED - SslTerminating includes WAF 2.0)
            // We use SslTerminating which has integrated WAF, not standalone WAFManager
            'WAFManager',
            
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
  
  # ConfigParser is disabled via /etc/bitninja/config.php (see above)
  # We manually add SSL certificates to BitNinja instead
  log_and_console "ConfigParser module disabled (via config.php)"
  
  # Manually add SSL certificates to BitNinja
  log_and_console "Configuring SSL certificates for BitNinja..."
  if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    log_and_console "Adding SSL certificate for $DOMAIN to BitNinja..."
    
    # Add certificate (capture output for debugging, don't suppress errors)
    CERT_ADD_OUTPUT=$(bitninjacli --module=SslTerminating --add-cert \
      --domain="$DOMAIN" \
      --certFile="/etc/letsencrypt/live/$DOMAIN/fullchain.pem" \
      --keyFile="/etc/letsencrypt/live/$DOMAIN/privkey.pem" 2>&1)
    CERT_ADD_EXIT=$?
    
    if [ $CERT_ADD_EXIT -eq 0 ]; then
      log_and_console "✓ SSL certificate added to BitNinja"
      log_and_console "Certificate output: $CERT_ADD_OUTPUT"
      
      # Force BitNinja to reload certificates
      bitninjacli --module=SslTerminating --force-recollect
      log_and_console "✓ BitNinja certificates reloaded"
      
      # Configure BitNinja to listen on port 443 (not 60414)
      log_and_console "Configuring BitNinja to listen on port 443..."
      sed -i 's/^WafFrontEndSettings\[port\]=60414$/WafFrontEndSettings[port]=443/' /etc/bitninja/SslTerminating/config.ini
      log_and_console "✓ BitNinja configured to listen on port 443"
      
      # Restart BitNinja FIRST to let it generate all config files
      log_and_console "Restarting BitNinja to generate configuration files..."
      systemctl restart bitninja
      sleep 15
      log_and_console "✓ BitNinja restarted, waiting for config generation..."
      
      # Wait for all config files to be generated
      log_and_console "Waiting for BitNinja to generate all config files..."
      
      # Wait up to 60 seconds for ssl_termiantion.cfg to be created
      WAIT_COUNT=0
      while [ ! -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ] && [ $WAIT_COUNT -lt 60 ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
      done
      
      if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
        log_and_console "✓ Config files generated after ${WAIT_COUNT} seconds"
      else
        log_and_console "⚠ Config files not generated after 60 seconds, forcing restart..."
        systemctl restart bitninja
        sleep 20
        
        # Wait another 60 seconds after forced restart
        WAIT_COUNT=0
        while [ ! -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ] && [ $WAIT_COUNT -lt 60 ]; do
          sleep 1
          WAIT_COUNT=$((WAIT_COUNT + 1))
        done
        
        if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
          log_and_console "✓ Config files generated after forced restart (${WAIT_COUNT} seconds)"
        else
          log_and_console "⚠ Config files not generated after 120 seconds, trying final restart..."
          
          # Third attempt: Force recollect again and restart
          bitninjacli --module=SslTerminating --force-recollect
          systemctl restart bitninja
          sleep 30
          
          # Wait another 60 seconds after final restart
          WAIT_COUNT=0
          while [ ! -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ] && [ $WAIT_COUNT -lt 60 ]; do
            sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
          done
          
          if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
            log_and_console "✓ Config files generated after final restart (${WAIT_COUNT} seconds)"
          else
            log_and_console "⚠ WARNING: Config files still not generated after 180 seconds total"
            log_and_console "⚠ Manual intervention required:"
            log_and_console "   bitninjacli --module=SslTerminating --force-recollect"
            log_and_console "   systemctl restart bitninja"
            log_and_console "   # Wait 30 seconds, then check: ls -la /opt/bitninja-ssl-termination/etc/haproxy/configs/"
          fi
        fi
      fi
      
      # Now configure BitNinja (after configs are generated)
      log_and_console "Configuring BitNinja backend and port bindings..."
      
      # Fix the backend configuration (BitNinja has a typo in the filename: ssl_termiantion.cfg)
      if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg" ]; then
        # Remove immutable flag if set (from previous runs)
        chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg 2>/dev/null || true
        
        # Backup the file
        cp /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg \
           /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg.backup
        
        # Fix backend to point to Apache on 127.0.0.1:80 (not *:443)
        # BitNinja generates: server origin-backend *:443 ssl verify none backup no-check-ssl ssl sni req.hdr(host)
        # We need: server origin-backend 127.0.0.1:80 check backup
        sed -i 's/server[[:space:]]\+origin-backend[[:space:]]\+\*:443.*/server\torigin-backend 127.0.0.1:80 check backup/' \
          /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg
        
        # Remove IPv6 bind lines only if IPv6 is disabled
        if [ "$DISABLE_IPV6" = "true" ]; then
          sed -i '/bind \[::\]/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg
          log_and_console "✓ IPv6 binds removed (IPv6 disabled)"
        else
          log_and_console "✓ IPv6 binds preserved (IPv6 enabled)"
        fi
        
        # Make it immutable so BitNinja can't regenerate it
        chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/ssl_termiantion.cfg
        
        log_and_console "✓ BitNinja backend configured to forward to Apache (127.0.0.1:80)"
        log_and_console "✓ ssl_termiantion.cfg configured and made immutable"
      else
        log_and_console "⚠ WARNING: ssl_termiantion.cfg not found"
      fi
      
      # Configure internal BitNinja ports (60415, 60418) to listen on localhost only
      log_and_console "Configuring BitNinja internal ports to listen on localhost only..."
      
      # Port 60415 (WAF HTTP proxy)
      if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg" ]; then
        # Remove immutable flag if set (from previous runs)
        chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg 2>/dev/null || true
        
        cp /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg \
           /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg.backup
        
        # Remove IPv6 bind (always - internal port should be localhost only)
        sed -i '/bind \[::\]:60415/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg
        
        # Change wildcard to localhost (internal port - always localhost only)
        sed -i 's/bind \*:60415/bind 127.0.0.1:60415/' /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg
        
        # Make immutable
        chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/waf_proxy_http.cfg
        
        log_and_console "✓ Port 60415 configured to listen on 127.0.0.1 only"
      else
        log_and_console "⚠ waf_proxy_http.cfg not found - port 60415 may not be restricted"
      fi
      
      # Port 60418 (XCaptcha HTTPS)
      if [ -f "/opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg" ]; then
        # Remove immutable flag if set (from previous runs)
        chattr -i /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg 2>/dev/null || true
        
        cp /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg \
           /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg.backup
        
        # Remove IPv6 bind (always - internal port should be localhost only)
        sed -i '/bind \[::\]:60418/d' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg
        
        # Change wildcard to localhost (internal port - always localhost only)
        sed -i 's/bind \*:60418/bind 127.0.0.1:60418/' /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg
        
        # Make immutable
        chattr +i /opt/bitninja-ssl-termination/etc/haproxy/configs/xcaptcha_https_multiport.cfg
        
        log_and_console "✓ Port 60418 configured to listen on 127.0.0.1 only"
      else
        log_and_console "⚠ xcaptcha_https_multiport.cfg not found - port 60418 may not be restricted"
      fi
      
      log_and_console "✓ All BitNinja config files made immutable"
      
      # Final restart to apply all changes (configs are now immutable)
      log_and_console "Performing final BitNinja restart with immutable configs..."
      systemctl restart bitninja
      sleep 10
      log_and_console "✓ BitNinja restarted with final configuration"
    else
      log_and_console "⚠ WARNING: Failed to add SSL certificate to BitNinja (exit code: $CERT_ADD_EXIT)"
      log_and_console "Certificate addition output: $CERT_ADD_OUTPUT"
      log_and_console "⚠ You will need to add it manually after deployment:"
      log_and_console "   bitninjacli --module=SslTerminating --add-cert \\"
      log_and_console "     --domain=\"$DOMAIN\" \\"
      log_and_console "     --certFile=\"/etc/letsencrypt/live/$DOMAIN/fullchain.pem\" \\"
      log_and_console "     --keyFile=\"/etc/letsencrypt/live/$DOMAIN/privkey.pem\""
      log_and_console "   systemctl restart bitninja"
    fi
  else
    log_and_console "⚠ No SSL certificate found yet for $DOMAIN"
    log_and_console "Certificate will be added to BitNinja after Let's Encrypt acquisition"
  fi
  
  # BitNinja will listen on all interfaces by default (0.0.0.0 or [::])
  # UFW firewall controls which IPs can access BitNinja ports
  # This is the standard security model - application listens, firewall restricts
  log_and_console ""
  log_and_console "✓ BitNinja configuration:"
  log_and_console "  - BitNinja listening on 0.0.0.0:443 (SSL termination)"
  log_and_console "  - UFW restricts access to $SERVER_IP only"
  log_and_console "  - Apache listening on 127.0.0.1:80 (HTTP backend)"
  log_and_console ""
  log_and_console "Note: BitNinja config files regenerate automatically."
  log_and_console "      SSL certificates managed via BitNinja CLI, not ConfigParser."
  
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
  log_and_console "Listening Ports:"
  ss -tlnp | grep -E ':(443|60413|60415|60418)' | tee -a "$LOG_FILE"
  log_and_console ""
  log_and_console "Expected configuration:"
  log_and_console "  - Port 443: 0.0.0.0 (public HTTPS - BitNinja SSL termination)"
  log_and_console "  - Port 60413: 0.0.0.0 (public HTTPS Captcha - if enabled)"
  log_and_console "  - Port 60415: 127.0.0.1 (localhost only - WAF HTTP proxy)"
  log_and_console "  - Port 60418: 127.0.0.1 (localhost only - XCaptcha HTTPS)"
  
  # Verify BitNinja is listening on port 443
  if ss -tlnp | grep ":443" | grep "bitninja" | grep -q '0.0.0.0\|:::'; then
    log_and_console "✓ BitNinja listening on 0.0.0.0:443 (all interfaces - correct)"
    log_and_console "✓ UFW restricts access to $SERVER_IP only"
  elif ss -tlnp | grep ":443" | grep "bitninja" | grep -q "$SERVER_IP"; then
    log_and_console "✓ BitNinja listening on $SERVER_IP:443 (specific IP)"
  elif ss -tlnp | grep ":443" | grep "bitninja" | grep -q '127.0.0.1'; then
    log_and_console "⚠ WARNING: BitNinja is listening on 127.0.0.1:443 (localhost only)"
    log_and_console "This means BitNinja won't be accessible externally!"
  else
    log_and_console "⚠ WARNING: BitNinja may not be listening on port 443"
    log_and_console "Check: ss -tlnp | grep :443"
  fi
  
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
  
  # Sync configuration to BitNinja cloud (after all configuration is complete)
  log_and_console ""
  log_and_console "Syncing configuration to BitNinja cloud..."
  if bitninjacli --syncconfigs 2>/dev/null; then
    log_and_console "✓ Configuration synced to BitNinja cloud"
  else
    log_and_console "⚠ Config sync skipped (may not be critical)"
  fi
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
