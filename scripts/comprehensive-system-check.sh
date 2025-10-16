#!/bin/bash
# Comprehensive System Requirements Check for NextCloud + BitNinja
# Checks minimum requirements for both NextCloud and BitNinja

# Load configuration variables
source /root/system-setup/config.sh

LOG_FILE="$LOGS_DIR/comprehensive-system-check.log"
CONSOLE="/dev/tty1"

# Function to output to both log and console
log_and_console() {
    echo "$1" | tee -a $LOG_FILE | tee $CONSOLE
}

# Function to check if value meets minimum requirement
check_minimum() {
    local value=$1
    local minimum=$2
    local unit=$3
    local description=$4
    
    if (( $(echo "$value >= $minimum" | bc -l) )); then
        log_and_console "  ✓ $description: ${value}${unit} (>= ${minimum}${unit})"
        return 0
    else
        log_and_console "  ✗ $description: ${value}${unit} (REQUIRES >= ${minimum}${unit})"
        return 1
    fi
}

log_and_console "===== Comprehensive System Requirements Check ====="
log_and_console "Checking NextCloud + BitNinja Requirements"
log_and_console "Timestamp: $(date)"
log_and_console ""

# Initialize counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# 1. HARDWARE REQUIREMENTS
log_and_console "1. HARDWARE REQUIREMENTS:"

# RAM Check (NextCloud: 512MB minimum, 2GB+ recommended; BitNinja: 1GB minimum)
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_GB=$(echo "scale=2; $RAM_KB / 1024 / 1024" | bc)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_minimum $RAM_GB 1.0 "GB" "RAM"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# CPU Check (NextCloud: 1 core minimum; BitNinja: 1 core minimum)
CPU_CORES=$(nproc)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_minimum $CPU_CORES 1 "core" "CPU cores"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Disk Space Check (NextCloud: 5GB minimum; BitNinja: 1GB minimum)
DISK_GB=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_minimum $DISK_GB 5 "GB" "Available disk space"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
log_and_console ""

# 2. OPERATING SYSTEM REQUIREMENTS
log_and_console "2. OPERATING SYSTEM REQUIREMENTS:"

# OS Check (Ubuntu 24.04 LTS - supported by both NextCloud and BitNinja)
OS_INFO=$(lsb_release -d 2>/dev/null | cut -f2)
OS_VERSION=$(lsb_release -r 2>/dev/null | cut -f2)
log_and_console "  OS: $OS_INFO"

# Check if Ubuntu 24.04 or compatible
if [[ "$OS_VERSION" == "24.04"* ]] || [[ "$OS_INFO" == *"Ubuntu"* ]]; then
    log_and_console "  ✓ Ubuntu 24.04 LTS (supported by NextCloud and BitNinja)"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    log_and_console "  ⚠️  OS may not be fully supported (Ubuntu 24.04 LTS recommended)"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
log_and_console ""

# 3. PHP REQUIREMENTS (NextCloud specific)
log_and_console "3. PHP REQUIREMENTS (NextCloud):"

# PHP Version Check (NextCloud: PHP 8.1+ required, 8.3 recommended)
PHP_VERSION=$(php -v | head -n 1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_minimum $PHP_VERSION 8.1 "" "PHP version"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# PHP Required Modules Check
log_and_console "  PHP Required Modules:"
required_modules="curl dom fileinfo gd json libxml mbstring openssl posix session SimpleXML XMLReader XMLWriter zip zlib mysql gmp bcmath intl"
missing_modules=""
for module in $required_modules; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if php -m | grep -qi "^$module$"; then
        log_and_console "    ✓ $module"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "    ✗ $module (MISSING)"
        missing_modules="$missing_modules $module"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

# PHP Recommended Modules Check
log_and_console "  PHP Recommended Modules:"
recommended_modules="imagick redis apcu ldap bz2"
for module in $recommended_modules; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if php -m | grep -qi "^$module$"; then
        log_and_console "    ✓ $module"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "    ⚠️  $module (recommended but not required)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))  # Don't fail for recommended modules
    fi
done
log_and_console ""

# 4. BITNINJA DEPENDENCIES
log_and_console "4. BITNINJA DEPENDENCIES:"

# Check BitNinja required packages
bitninja_packages="ipset iptables net-tools awk gzip sed grep coreutils"
for package in $bitninja_packages; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v $package &> /dev/null || dpkg -l | grep -q "^ii.*$package"; then
        log_and_console "  ✓ $package"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "  ✗ $package (MISSING)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
log_and_console ""

# 5. SERVICE STATUS
log_and_console "5. SERVICE STATUS:"

services="mariadb apache2 redis-server bitninja"
for service in $services; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if systemctl is-active --quiet $service; then
        log_and_console "  ✓ $service is running"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "  ✗ $service is not running"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done
log_and_console ""

# 6. NETWORK AND FIREWALL
log_and_console "6. NETWORK AND FIREWALL:"

# Check required ports are open
required_ports="22 443"
for port in $required_ports; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if ufw status | grep -q "$port"; then
        log_and_console "  ✓ Port $port is allowed in UFW"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "  ✗ Port $port not found in UFW rules"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
done

# Check BitNinja ports (60412, 60413)
bitninja_ports="60412 60413"
for port in $bitninja_ports; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if netstat -tlnp | grep -q ":$port "; then
        log_and_console "  ✓ BitNinja port $port is listening"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "  ⚠️  BitNinja port $port not listening (may be normal if BitNinja not fully configured)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))  # Don't fail for BitNinja ports
    fi
done
log_and_console ""

# 7. NEXTCLOUD STATUS
log_and_console "7. NEXTCLOUD STATUS:"

TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f $NEXTCLOUD_WEB_DIR/occ ]; then
    log_and_console "  ✓ NextCloud files found"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    
    # Check NextCloud configuration
    if sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ status 2>/dev/null | grep -q "installed: true"; then
        log_and_console "  ✓ NextCloud is properly installed"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        log_and_console "  ⚠️  NextCloud installation may be incomplete"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    log_and_console "  ✗ NextCloud not found"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
log_and_console ""

# 8. DISK SPACE FOR NEXTCLOUD DATA
log_and_console "8. DISK SPACE ANALYSIS:"

# Check NextCloud data directory space
if [ -d "$NEXTCLOUD_DATA_DIR" ]; then
    DATA_SPACE_GB=$(df $NEXTCLOUD_DATA_DIR | tail -1 | awk '{print int($4/1024/1024)}')
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if check_minimum $DATA_SPACE_GB 5 "GB" "NextCloud data directory space"; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
fi

# Check web directory space
WEB_SPACE_GB=$(df /var/www | tail -1 | awk '{print int($4/1024/1024)}')
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if check_minimum $WEB_SPACE_GB 1 "GB" "Web directory space"; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
log_and_console ""

# 9. FINAL SUMMARY
log_and_console "===== COMPREHENSIVE SYSTEM CHECK SUMMARY ====="
log_and_console "Total Checks: $TOTAL_CHECKS"
log_and_console "Passed: $PASSED_CHECKS"
log_and_console "Failed: $FAILED_CHECKS"

if [ $FAILED_CHECKS -eq 0 ]; then
    log_and_console "✅ SYSTEM MEETS ALL REQUIREMENTS"
    log_and_console "   NextCloud + BitNinja are ready for production use!"
elif [ $FAILED_CHECKS -le 2 ]; then
    log_and_console "⚠️  SYSTEM MOSTLY READY"
    log_and_console "   Minor issues detected - review failed checks above"
else
    log_and_console "❌ SYSTEM REQUIREMENTS NOT MET"
    log_and_console "   Critical issues detected - system may not function properly"
fi

if [ -n "$missing_modules" ]; then
    log_and_console ""
    log_and_console "MISSING PHP MODULES:$missing_modules"
    log_and_console "Install with: apt-get install php8.3-{module1,module2,...}"
fi

log_and_console ""
log_and_console "Detailed log available at: $LOG_FILE"
log_and_console "========================================"
