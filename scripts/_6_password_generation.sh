#!/bin/bash
# Password Generation Script
# Generates secure passwords for all services

source /root/system-setup/config.sh
log_and_console "=== GENERATING SECURE PASSWORDS ==="
DB_PASS_GEN=$(apg -n 1 -m 16 -x 16 -M NCL)
DB_ROOT_PASS_GEN=$(apg -n 1 -m 16 -x 16 -M NCL)
NEXTCLOUD_ADMIN_PASS_GEN=$(apg -n 1 -m 12 -x 12 -M NCL)

# Store passwords securely
echo "DB_PASS=$DB_PASS_GEN" > /root/system-setup/.passwords
echo "DB_ROOT_PASS=$DB_ROOT_PASS_GEN" >> /root/system-setup/.passwords
echo "NEXTCLOUD_ADMIN_PASS=$NEXTCLOUD_ADMIN_PASS_GEN" >> /root/system-setup/.passwords
chmod 600 /root/system-setup/.passwords
log_and_console "✓ Secure passwords generated and stored"
