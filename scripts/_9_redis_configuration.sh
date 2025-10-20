#!/bin/bash
# Redis Caching Setup Script
# Configures Redis cache with security hardening

source /root/system-setup/config.sh
log_and_console "=== REDIS CACHING SETUP ==="
log_and_console "Configuring Redis cache..."
systemctl start redis-server && systemctl enable redis-server

# Redis security configuration
if [ "$BIND_LOCALHOST" = "true" ]; then
  sed -i 's/^# bind 127.0.0.1 ::1/bind 127.0.0.1/; s/^protected-mode yes/protected-mode yes/' /etc/redis/redis.conf
fi
echo -e 'rename-command FLUSHDB ""\nrename-command FLUSHALL ""\nrename-command KEYS ""\nrename-command CONFIG ""\nrename-command EVAL ""' >> /etc/redis/redis.conf
systemctl restart redis-server
log_and_console "✓ Redis configured with security hardening"
