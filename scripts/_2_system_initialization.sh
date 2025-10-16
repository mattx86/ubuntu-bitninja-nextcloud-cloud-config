#!/bin/bash
# System Initialization Script
# Sets hostname, timezone, and basic system configuration

source /root/system-setup/config.sh
log_and_console "=== SYSTEM INITIALIZATION ==="
log_and_console "Setting system hostname and timezone..."
hostnamectl set-hostname "$DOMAIN"
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.0.1 $DOMAIN" >> /etc/hosts
timedatectl set-timezone "$TIMEZONE"
log_and_console "✓ System initialized: $DOMAIN ($TIMEZONE)"
