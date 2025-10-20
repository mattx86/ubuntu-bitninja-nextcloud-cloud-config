#!/bin/bash
# System Update Script
# Performs full system update with apt-get

source /root/system-setup/config.sh
log_and_console "=== SYSTEM UPDATE ==="

# Set non-interactive mode for all apt operations
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Update package lists
log_and_console "Running apt-get update..."
apt-get update -y 2>&1 | tee -a "$LOG_FILE" | tee "$CONSOLE" || { log_and_console "ERROR: apt-get update failed"; exit 1; }

# Upgrade installed packages
log_and_console "Running apt-get upgrade..."
apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | tee -a "$LOG_FILE" | tee "$CONSOLE" || { log_and_console "ERROR: apt-get upgrade failed"; exit 1; }

# Perform distribution upgrade
log_and_console "Running apt-get dist-upgrade..."
apt-get dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" 2>&1 | tee -a "$LOG_FILE" | tee "$CONSOLE" || { log_and_console "ERROR: apt-get dist-upgrade failed"; exit 1; }

# Clean up
log_and_console "Cleaning up unnecessary packages..."
apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE" | tee "$CONSOLE"
apt-get autoclean -y 2>&1 | tee -a "$LOG_FILE" | tee "$CONSOLE"

log_and_console "✓ System update completed successfully"

