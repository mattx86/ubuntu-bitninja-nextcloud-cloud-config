#!/bin/bash
# NextCloud Installation Script
# Downloads, installs, and configures NextCloud

source /root/system-setup/config.sh
log_and_console "=== NEXTCLOUD INSTALLATION ==="
log_and_console "Downloading and installing NextCloud..."
cd "$DOWNLOADS_DIR" && \
wget --tries=3 --timeout=60 --show-progress https://download.nextcloud.com/server/releases/latest.zip -O nextcloud.zip && \
chmod 600 nextcloud.zip && \
unzip -q nextcloud.zip && \
mv nextcloud "$NEXTCLOUD_WEB_DIR" && \
chown -R www-data:www-data "$NEXTCLOUD_WEB_DIR" && \
chmod -R 755 "$NEXTCLOUD_WEB_DIR" && \
log_and_console "✓ NextCloud installed to $NEXTCLOUD_WEB_DIR"

log_and_console "Creating NextCloud data directory..."
mkdir -p "$NEXTCLOUD_DATA_DIR" && chown -R www-data:www-data "$NEXTCLOUD_DATA_DIR" && chmod -R 755 "$NEXTCLOUD_DATA_DIR"
log_and_console "✓ NextCloud data directory created"

log_and_console "Installing Nextcloud via command line..."
cd "$NEXTCLOUD_WEB_DIR"

sudo -u www-data php occ maintenance:install \
  --database "mysql" \
  --database-name "$DB_NAME" \
  --database-user "$DB_USER" \
  --database-pass "$DB_PASS" \
  --admin-user "$NEXTCLOUD_ADMIN_USER" \
  --admin-pass "$NEXTCLOUD_ADMIN_PASS" \
  --data-dir "$NEXTCLOUD_DATA_DIR"

if [ $? -ne 0 ]; then
    log_and_console "ERROR: Nextcloud installation failed"
    exit 1
fi

log_and_console "Configuring Nextcloud settings..."

# Add trusted domains
sudo -u www-data php occ config:system:set trusted_domains 0 --value="$DOMAIN"
sudo -u www-data php occ config:system:set trusted_domains 1 --value="localhost"

# Configure Redis for caching and file locking
sudo -u www-data php occ config:system:set redis host --value="localhost"
sudo -u www-data php occ config:system:set redis port --value="6379"
sudo -u www-data php occ config:system:set memcache.local --value="\OC\Memcache\APCu"
sudo -u www-data php occ config:system:set memcache.distributed --value="\OC\Memcache\Redis"
sudo -u www-data php occ config:system:set memcache.locking --value="\OC\Memcache\Redis"

# Configure default phone region (recommended)
sudo -u www-data php occ config:system:set default_phone_region --value="US"

# Set up background jobs to use cron (recommended)
sudo -u www-data php occ background:cron

# Configure additional recommended settings
sudo -u www-data php occ config:system:set default_language --value="en"
sudo -u www-data php occ config:system:set default_locale --value="en_US"

# Enable recommended apps
sudo -u www-data php occ app:enable files_external

# Set proper permissions
chown -R www-data:www-data "$NEXTCLOUD_WEB_DIR"
chown -R www-data:www-data "$NEXTCLOUD_DATA_DIR"

# NextCloud Security Configuration
sudo -u www-data php occ config:system:set trusted_proxies 0 --value="127.0.0.1"
sudo -u www-data php occ config:system:set overwrite.cli.url --value="http://localhost"
sudo -u www-data php occ config:system:set overwriteprotocol --value="https"
sudo -u www-data php occ config:system:set overwritehost --value="$DOMAIN"

# Enable MySQL 4-byte support for emoji functionality
sudo -u www-data php occ config:system:set mysql.utf8mb4 --type boolean --value="true"
sudo -u www-data php occ maintenance:repair

# Set up cron job for Nextcloud background tasks
log_and_console "Setting up cron job for background tasks..."
(crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f $NEXTCLOUD_WEB_DIR/cron.php") | crontab -u www-data -

log_and_console "✓ NextCloud CLI installation and configuration completed"
log_and_console "  - Admin username: $NEXTCLOUD_ADMIN_USER"
log_and_console "  - Admin password: ******** (see /root/system-setup/.passwords)"

log_and_console "=== APACHE VIRTUAL HOST CONFIGURATION ==="
log_and_console "Downloading Apache NextCloud configuration..."
wget --tries=3 --timeout=30 -O /etc/apache2/sites-available/nextcloud.conf "$GITHUB_RAW_URL/conf/nextcloud-apache-vhost.conf" || { log_and_console "ERROR: Failed to download nextcloud-apache-vhost.conf"; exit 1; }
chown root:root /etc/apache2/sites-available/nextcloud.conf
chmod 644 /etc/apache2/sites-available/nextcloud.conf
sed -i "s|\$DOMAIN|$DOMAIN|g" /etc/apache2/sites-available/nextcloud.conf
sed -i "s|\$ADMIN_EMAIL|$ADMIN_EMAIL|g" /etc/apache2/sites-available/nextcloud.conf
sed -i "s|\$NEXTCLOUD_WEB_DIR|$NEXTCLOUD_WEB_DIR|g" /etc/apache2/sites-available/nextcloud.conf
a2ensite nextcloud.conf
systemctl reload apache2
log_and_console "✓ Apache virtual host configured"
