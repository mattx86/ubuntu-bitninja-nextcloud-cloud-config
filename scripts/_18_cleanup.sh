#!/bin/bash
# Cleanup Script
# Performs final system cleanup

source /root/system-setup/config.sh
log_and_console "=== CLEANUP ==="
log_and_console "Performing final cleanup..."
apt-get autoremove -y && apt-get clean
rm -f "$DOWNLOADS_DIR/nextcloud.zip"
rm -f "$DOWNLOADS_DIR/bitninja-install.sh"
log_and_console "✓ System cleanup completed"
