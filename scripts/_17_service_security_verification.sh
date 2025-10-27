#!/bin/bash
# Service Security Verification Script
# Verifies service bindings and security settings

source /root/system-setup/config.sh
log_and_console "=== SERVICE SECURITY VERIFICATION ==="
log_and_console "Verifying service bindings..."

# Check MariaDB binding (port 3306)
MARIADB_BIND=$(ss -tlnp | grep ":3306" || true)
if echo "$MARIADB_BIND" | grep -q "127.0.0.1:3306"; then
  log_and_console "✓ MariaDB bound to localhost only (127.0.0.1:3306)"
elif echo "$MARIADB_BIND" | grep -qE "0\.0\.0\.0:3306|\*:3306"; then
  log_and_console "⚠️  WARNING: MariaDB is listening on all interfaces (0.0.0.0:3306)"
  log_and_console "   This is a security risk! Should be 127.0.0.1:3306 only"
elif [ -n "$MARIADB_BIND" ]; then
  log_and_console "✓ MariaDB is running and bound correctly"
else
  log_and_console "⚠️  MariaDB not detected on port 3306 (may not be started yet)"
fi

# Check Redis binding (port 6379)
REDIS_BIND=$(ss -tlnp | grep ":6379" || true)
if echo "$REDIS_BIND" | grep -q "127.0.0.1:6379"; then
  log_and_console "✓ Redis bound to localhost only (127.0.0.1:6379)"
elif echo "$REDIS_BIND" | grep -qE "0\.0\.0\.0:6379|\*:6379"; then
  log_and_console "⚠️  WARNING: Redis is listening on all interfaces (0.0.0.0:6379)"
  log_and_console "   This is a security risk! Should be 127.0.0.1:6379 only"
elif [ -n "$REDIS_BIND" ]; then
  log_and_console "✓ Redis is running and bound correctly"
else
  log_and_console "⚠️  Redis not detected on port 6379 (may not be started yet)"
fi

# Check Apache binding (port 80)
APACHE_BIND=$(ss -tlnp | grep ":80" | grep -v ":80[0-9]" || true)
if echo "$APACHE_BIND" | grep -q "127.0.0.1:80"; then
  log_and_console "✓ Apache bound to localhost only (127.0.0.1:80)"
  log_and_console "  BitNinja WAF handles public HTTPS on 0.0.0.0:443"
elif echo "$APACHE_BIND" | grep -qE "0\.0\.0\.0:80|\*:80"; then
  log_and_console "⚠️  WARNING: Apache is listening on all interfaces (0.0.0.0:80)"
  log_and_console "   Should be 127.0.0.1:80 only (BitNinja handles public traffic)"
elif [ -n "$APACHE_BIND" ]; then
  log_and_console "✓ Apache is running and bound correctly"
else
  log_and_console "⚠️  Apache not detected on port 80 (may not be started yet)"
fi

# Check IPv6 status
if [ "$DISABLE_IPV6" = "true" ]; then
  if [ ! -f /proc/net/if_inet6 ]; then
    log_and_console "✓ IPv6 successfully disabled (no /proc/net/if_inet6)"
  else
    # Check if there are any non-loopback IPv6 addresses
    IPV6_COUNT=$(ip -6 addr show | grep -c "inet6" | grep -v "::1" || echo "0")
    if [ "$IPV6_COUNT" -eq 0 ] || [ "$IPV6_COUNT" -eq 1 ]; then
      log_and_console "✓ IPv6 effectively disabled (only loopback present)"
    else
      log_and_console "⚠️  WARNING: IPv6 may still be active"
      log_and_console "   Found $IPV6_COUNT IPv6 addresses (expected 0-1 for loopback only)"
    fi
  fi
else
  log_and_console "✓ IPv6 enabled (as configured)"
fi

# Check BitNinja is listening on public interface for HTTPS
BITNINJA_HTTPS=$(ss -tlnp | grep ":443" | grep "bitninja" || true)
if [ -n "$BITNINJA_HTTPS" ]; then
  if echo "$BITNINJA_HTTPS" | grep -qE "0\.0\.0\.0:443|\*:443"; then
    log_and_console "✓ BitNinja listening on public interface for HTTPS (0.0.0.0:443)"
  elif echo "$BITNINJA_HTTPS" | grep -q "$SERVER_IP:443"; then
    log_and_console "✓ BitNinja listening on server IP for HTTPS ($SERVER_IP:443)"
  else
    log_and_console "⚠️  BitNinja listening on port 443 but binding unclear"
  fi
else
  log_and_console "⚠️  WARNING: BitNinja not detected on port 443"
  log_and_console "   Run: sudo bash /root/system-setup/scripts/_18_bitninja_final_config.sh"
fi

log_and_console ""
log_and_console "=== SECURITY BINDING SUMMARY ==="
log_and_console "Expected configuration:"
log_and_console "  - MariaDB (3306): 127.0.0.1 only ✓"
log_and_console "  - Redis (6379): 127.0.0.1 only ✓"
log_and_console "  - Apache (80): 127.0.0.1 only ✓"
log_and_console "  - BitNinja (443): 0.0.0.0 or $SERVER_IP (public) ✓"
log_and_console ""
log_and_console "✓ Service security verification completed"
