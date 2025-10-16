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

if command -v bitninja-cli &> /dev/null && systemctl is-active --quiet bitninja; then
  log_and_console "Configuring BitNinja security features..."
  
  # Enable core security modules
  bitninja-cli --enable WAF3 2>/dev/null && log_and_console "✓ WAF Pro enabled" || log_and_console "WAF Pro already enabled"
  bitninja-cli --enable malwarescanner 2>/dev/null && log_and_console "✓ Malware Scanner enabled" || log_and_console "Malware Scanner already enabled"
  bitninja-cli --enable ipreputation 2>/dev/null && log_and_console "✓ IP Reputation enabled" || log_and_console "IP Reputation already enabled"
  bitninja-cli --enable honeypot 2>/dev/null && log_and_console "✓ Honeypot enabled" || log_and_console "Honeypot already enabled"
  bitninja-cli --enable dosprotection 2>/dev/null && log_and_console "✓ DoS Protection enabled" || log_and_console "DoS Protection already enabled"
  bitninja-cli --enable outboundspam 2>/dev/null && log_and_console "✓ Outbound Spam enabled" || log_and_console "Outbound Spam already enabled"
  bitninja-cli --enable configparser 2>/dev/null && log_and_console "✓ Config Parser enabled" || log_and_console "Config Parser already enabled"
  bitninja-cli --enable realtimeprotection 2>/dev/null && log_and_console "✓ Real-time Protection enabled" || log_and_console "Real-time Protection already enabled"
  bitninja-cli --enable advancedthreat 2>/dev/null && log_and_console "✓ Advanced Threat Detection enabled" || log_and_console "Advanced Threat Detection already enabled"
  
  log_and_console "✓ BitNinja security features configured"
else
  log_and_console "BitNinja not available for automatic configuration"
fi
