#!/bin/bash
# Service Security Verification Script
# Verifies service bindings and security settings

source /root/system-setup/config.sh
log_and_console "=== SERVICE SECURITY VERIFICATION ==="
log_and_console "Verifying service bindings..."

# Check service bindings
if ss -tlnp | grep -q ":3306.*127.0.0.1"; then
  log_and_console "✓ MariaDB bound to localhost only"
else
  log_and_console "⚠️  MariaDB may not be bound to localhost only"
fi

if ss -tlnp | grep -q ":6379.*127.0.0.1"; then
  log_and_console "✓ Redis bound to localhost only"
else
  log_and_console "⚠️  Redis may not be bound to localhost only"
fi

if ss -tlnp | grep -q ":80.*127.0.0.1"; then
  log_and_console "✓ Apache bound to localhost only (BitNinja WAF handles HTTPS)"
else
  log_and_console "⚠️  Apache may not be bound to localhost only"
fi

if [ "$DISABLE_IPV6" = "true" ]; then
  if [ ! -f /proc/net/if_inet6 ]; then
    log_and_console "✓ IPv6 successfully disabled"
  else
    log_and_console "⚠️  IPv6 may still be enabled"
  fi
fi

log_and_console "✓ Service security verification completed"
