#!/bin/bash
# MariaDB Database Setup Script
# Configures MariaDB database and security

source /root/system-setup/config.sh
log_and_console "=== MARIADB DATABASE SETUP ==="
log_and_console "Starting and enabling MariaDB..."
systemctl start mariadb && systemctl enable mariadb

log_and_console "Downloading MariaDB configuration..."
wget --tries=3 --timeout=30 -O /etc/mysql/mariadb.conf.d/60-nextcloud.cnf "$GITHUB_RAW_URL/conf/nextcloud-mariadb.cnf" || { log_and_console "ERROR: Failed to download nextcloud-mariadb.cnf"; exit 1; }
chown root:root /etc/mysql/mariadb.conf.d/60-nextcloud.cnf
chmod 644 /etc/mysql/mariadb.conf.d/60-nextcloud.cnf
sed -i "s|\$MARIADB_BUFFER_POOL|$MARIADB_BUFFER_POOL|g" /etc/mysql/mariadb.conf.d/60-nextcloud.cnf
sed -i "s|\$MARIADB_IO_CAPACITY|$MARIADB_IO_CAPACITY|g" /etc/mysql/mariadb.conf.d/60-nextcloud.cnf
sed -i "s|\$MARIADB_MAX_CONNECTIONS|$MARIADB_MAX_CONNECTIONS|g" /etc/mysql/mariadb.conf.d/60-nextcloud.cnf
systemctl restart mariadb
log_and_console "✓ MariaDB configured and restarted"

log_and_console "Creating NextCloud database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
log_and_console "✓ NextCloud database and user created"

log_and_console "Applying MariaDB security hardening..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASS'; DELETE FROM mysql.user WHERE User=''; DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1'); DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;"
log_and_console "✓ MariaDB security hardening completed"
