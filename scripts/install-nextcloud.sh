#!/bin/bash
# NextCloud installation script
# Usage: ./install-nextcloud.sh

# Load configuration variables
source /root/system-setup/config.sh

echo "Installing Nextcloud via command line..."
cd $NEXTCLOUD_WEB_DIR

sudo -u www-data php occ maintenance:install \
  --database "mysql" \
  --database-name "$DB_NAME" \
  --database-user "$DB_USER" \
  --database-pass "$DB_PASS" \
  --admin-user "$NEXTCLOUD_ADMIN_USER" \
  --admin-pass "$NEXTCLOUD_ADMIN_PASS" \
  --data-dir "$NEXTCLOUD_DATA_DIR"

echo "Configuring Nextcloud settings..."

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
chown -R www-data:www-data $NEXTCLOUD_WEB_DIR
chown -R www-data:www-data $NEXTCLOUD_DATA_DIR

# NextCloud Security Configuration
sudo -u www-data php occ config:system:set trusted_proxies 0 --value="127.0.0.1"
sudo -u www-data php occ config:system:set overwrite.cli.url --value="http://localhost"
sudo -u www-data php occ config:system:set overwriteprotocol --value="https"
sudo -u www-data php occ config:system:set overwritehost --value="$DOMAIN"

# Enable MySQL 4-byte support for emoji functionality
sudo -u www-data php occ config:system:set mysql.utf8mb4 --type boolean --value="true"
sudo -u www-data php occ maintenance:repair

# Set up cron job for Nextcloud background tasks
echo "Setting up cron job for background tasks..."
(crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php -f $NEXTCLOUD_WEB_DIR/cron.php") | crontab -u www-data -

echo ""
echo "========================================"
echo "NextCloud installation complete!"
echo "========================================"
echo "  - Admin username: $NEXTCLOUD_ADMIN_USER"
echo "  - Admin password: $NEXTCLOUD_ADMIN_PASS"
echo ""
echo "After DNS is configured, configure SSL certificates in BitNinja dashboard"
echo "========================================"
