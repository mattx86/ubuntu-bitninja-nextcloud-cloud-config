#!/bin/bash
# Unattended Upgrades Configuration
# Configures automatic security updates
# 
# This runs LAST to ensure it doesn't interfere with deployment package installations

source /root/system-setup/config.sh
log_and_console "=== UNATTENDED UPGRADES CONFIGURATION ==="

# Install unattended-upgrades package if not already installed
log_and_console "Checking unattended-upgrades package..."
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Check if already installed
if dpkg -l | grep -q "^ii.*unattended-upgrades"; then
  log_and_console "✓ unattended-upgrades already installed"
else
  log_and_console "Installing unattended-upgrades package..."
  apt-get update -y
  apt-get install -y unattended-upgrades apt-listchanges || { 
    log_and_console "⚠ WARNING: Failed to install unattended-upgrades"
    log_and_console "Continuing anyway - you can install manually later"
    log_and_console "Command: sudo apt-get install -y unattended-upgrades apt-listchanges"
  }
  
  # Verify installation
  if dpkg -l | grep -q "^ii.*unattended-upgrades"; then
    log_and_console "✓ unattended-upgrades package installed"
  else
    log_and_console "⚠ WARNING: unattended-upgrades not installed - skipping configuration"
    exit 0
  fi
fi

# Download and configure unattended-upgrades
log_and_console "Downloading unattended upgrades configuration..."
wget --tries=3 --timeout=30 -O /etc/apt/apt.conf.d/50unattended-upgrades "$GITHUB_RAW_URL/conf/50ubuntu-unattended-upgrades" || { log_and_console "ERROR: Failed to download 50ubuntu-unattended-upgrades"; exit 1; }
chown root:root /etc/apt/apt.conf.d/50unattended-upgrades
chmod 644 /etc/apt/apt.conf.d/50unattended-upgrades
log_and_console "✓ Unattended upgrades configuration downloaded"

# Enable automatic updates
log_and_console "Enabling automatic security updates..."
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

chown root:root /etc/apt/apt.conf.d/20auto-upgrades
chmod 644 /etc/apt/apt.conf.d/20auto-upgrades
log_and_console "✓ Automatic updates enabled"

# Verify configuration
log_and_console "Verifying unattended-upgrades configuration..."
if systemctl is-enabled unattended-upgrades.service &>/dev/null; then
  log_and_console "✓ unattended-upgrades service is enabled"
else
  systemctl enable unattended-upgrades.service
  log_and_console "✓ unattended-upgrades service enabled"
fi

# Test the configuration (dry-run)
log_and_console "Testing unattended-upgrades configuration (dry-run)..."
unattended-upgrade --dry-run --debug 2>&1 | head -20 | tee -a "$LOG_FILE"
log_and_console "✓ Configuration test complete"

log_and_console ""
log_and_console "=== UNATTENDED UPGRADES SUMMARY ==="
log_and_console "✓ Automatic security updates enabled"
log_and_console "✓ Updates will be checked daily"
log_and_console "✓ Security updates will be installed automatically"
log_and_console "✓ System will reboot automatically if required (configurable)"
log_and_console ""
log_and_console "Configuration files:"
log_and_console "  - /etc/apt/apt.conf.d/50unattended-upgrades (main config)"
log_and_console "  - /etc/apt/apt.conf.d/20auto-upgrades (schedule)"
log_and_console ""
log_and_console "To check status: systemctl status unattended-upgrades"
log_and_console "To check logs: tail -f /var/log/unattended-upgrades/unattended-upgrades.log"
log_and_console ""
log_and_console "✓ Unattended upgrades configuration completed"

