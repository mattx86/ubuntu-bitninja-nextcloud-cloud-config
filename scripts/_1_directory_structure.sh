#!/bin/bash
# Directory Structure Creation Script
# Creates system setup directory structure

# Create directories first (before sourcing config.sh which needs logs directory)
mkdir -p /root/system-setup/{scripts,logs,downloads}
chmod 700 /root/system-setup
chmod 700 /root/system-setup/scripts
chmod 700 /root/system-setup/logs
chmod 700 /root/system-setup/downloads

# Create and secure log files
touch /root/system-setup/logs/deployment.log
touch /root/system-setup/logs/system-verification.log
chmod 600 /root/system-setup/logs/deployment.log
chmod 600 /root/system-setup/logs/system-verification.log

source /root/system-setup/config.sh
log_and_console "=== CREATING DIRECTORY STRUCTURE ==="
log_and_console "✓ System setup directories created with secure permissions (700)"
log_and_console "✓ Log files created with secure permissions (600)"
