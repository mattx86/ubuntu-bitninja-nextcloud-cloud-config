#!/bin/bash
# System Optimization Script
# Applies system performance optimizations

source /root/system-setup/config.sh
log_and_console "=== SYSTEM OPTIMIZATION ==="
log_and_console "Applying system performance optimizations..."
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "net.core.rmem_max = 16777216" >> /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" >> /etc/sysctl.conf
sysctl -p
log_and_console "✓ System performance optimizations applied"
