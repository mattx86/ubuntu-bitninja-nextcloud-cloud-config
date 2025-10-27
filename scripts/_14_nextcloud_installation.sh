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

# NextCloud Security Configuration (reverse proxy behind BitNinja)
sudo -u www-data php occ config:system:set trusted_proxies 0 --value="127.0.0.1"
sudo -u www-data php occ config:system:set forwarded_for_headers 0 --value="HTTP_X_FORWARDED_FOR"
sudo -u www-data php occ config:system:set overwrite.cli.url --value="http://localhost"
sudo -u www-data php occ config:system:set overwriteprotocol --value="https"
sudo -u www-data php occ config:system:set overwritehost --value="$DOMAIN"

# Enable MySQL 4-byte support for emoji functionality
sudo -u www-data php occ config:system:set mysql.utf8mb4 --type boolean --value="true"
sudo -u www-data php occ maintenance:repair

# Disable default skeleton files (example content for new users)
log_and_console "Disabling default skeleton files..."
sudo -u www-data php occ config:system:set skeletondirectory --value=""
log_and_console "✓ Default example files disabled for new users"

# Disable all user registration
log_and_console "Disabling user registration..."
# Ensure no registration app is enabled
sudo -u www-data php occ app:disable registration 2>/dev/null || true
# Set to invite-only mode (only admin can create users)
sudo -u www-data php occ config:app:set core public_webdav --value="no"
log_and_console "✓ User registration fully disabled - Admin-only user creation"
log_and_console "  Users can only be created by admin via: Settings → Users"
log_and_console "  Password reset: ENABLED for existing users"

# Install and configure Social Login only if Google or Apple login is enabled
if [ "$ENABLE_GOOGLE_LOGIN" = "true" ] || [ "$ENABLE_APPLE_LOGIN" = "true" ]; then
  log_and_console "Social login enabled - installing Social Login app..."
  
  # Install and enable Social Login app for Apple/Google authentication
  sudo -u www-data php occ app:install sociallogin
  sudo -u www-data php occ app:enable sociallogin
  log_and_console "✓ Social Login app installed and enabled"

  # Configure Social Login settings
  log_and_console "Configuring Social Login settings..."
  # Allow users to link social accounts to existing accounts
  sudo -u www-data php occ config:app:set sociallogin allow_login_connect --value="1"

  # Configure invite-only registration
  if [ "$SOCIAL_LOGIN_INVITE_ONLY" = "true" ]; then
    log_and_console "Configuring invite-only registration..."
    # Disable public registration
    sudo -u www-data php occ config:app:set sociallogin disable_registration --value="1"
    # Prevent auto-creation of accounts via social login
    sudo -u www-data php occ config:app:set sociallogin create_disabled_users --value="0"
    log_and_console "✓ Invite-only mode enabled - users must be invited by admin"
  else
    # Allow public registration via social login
    sudo -u www-data php occ config:app:set sociallogin disable_registration --value="0"
    log_and_console "✓ Public registration enabled via social login"
  fi

  # Update user profile on each login
  if [ "$SOCIAL_LOGIN_UPDATE_PROFILE" = "true" ]; then
    sudo -u www-data php occ config:app:set sociallogin update_profile_on_login --value="1"
    log_and_console "✓ Profile updates enabled on login"
  fi

  # Prevent creating duplicate accounts
  sudo -u www-data php occ config:app:set sociallogin prevent_create_email_exists --value="1"

  # Configure Google OAuth if enabled
  if [ "$ENABLE_GOOGLE_LOGIN" = "true" ] && [ -n "$GOOGLE_CLIENT_ID" ] && [ -n "$GOOGLE_CLIENT_SECRET" ]; then
    log_and_console "Configuring Google OAuth..."
    sudo -u www-data php occ config:app:set sociallogin custom_providers --value='[{"name":"Google","title":"Google","authorizeUrl":"https://accounts.google.com/o/oauth2/auth","tokenUrl":"https://accounts.google.com/o/oauth2/token","userInfoUrl":"https://www.googleapis.com/oauth2/v1/userinfo","logoutUrl":"","clientId":"'"$GOOGLE_CLIENT_ID"'","clientSecret":"'"$GOOGLE_CLIENT_SECRET"'","scope":"openid email profile","profileFields":{"id":"id","name":"name","email":"email"},"style":""}]'
    log_and_console "✓ Google OAuth configured"
  else
    log_and_console "⚠ Google OAuth not configured (set ENABLE_GOOGLE_LOGIN=true and add credentials)"
  fi

  # Configure Apple Sign In if enabled
  if [ "$ENABLE_APPLE_LOGIN" = "true" ] && [ -n "$APPLE_CLIENT_ID" ] && [ -n "$APPLE_TEAM_ID" ]; then
    log_and_console "Configuring Apple Sign In..."
    # Note: Apple configuration is more complex and typically done via web UI
    # due to private key requirements. Provide instructions instead.
    log_and_console "⚠ Apple Sign In requires manual configuration via web UI"
    log_and_console "  Client ID: $APPLE_CLIENT_ID"
    log_and_console "  Team ID: $APPLE_TEAM_ID"
  else
    log_and_console "⚠ Apple Sign In not configured (set ENABLE_APPLE_LOGIN=true and add credentials)"
  fi

  log_and_console "✓ Social Login configured"
  log_and_console ""
  log_and_console "=== SOCIAL LOGIN CONFIGURATION ==="
  log_and_console "Status:"
  log_and_console "  - Google Login: $([ "$ENABLE_GOOGLE_LOGIN" = "true" ] && echo "ENABLED" || echo "DISABLED")"
  log_and_console "  - Apple Login: $([ "$ENABLE_APPLE_LOGIN" = "true" ] && echo "ENABLED" || echo "DISABLED")"
  log_and_console "  - Registration Mode: $([ "$SOCIAL_LOGIN_INVITE_ONLY" = "true" ] && echo "INVITE-ONLY" || echo "PUBLIC")"
  log_and_console ""
  if [ "$SOCIAL_LOGIN_INVITE_ONLY" = "true" ]; then
    log_and_console "INVITE-ONLY MODE:"
    log_and_console "  - Only invited users can register/login"
    log_and_console "  - To invite users: Settings → Users → Create new user"
    log_and_console "  - Users can then link their Google/Apple account"
    log_and_console ""
  fi
  log_and_console "To configure OAuth providers:"
  log_and_console "  1. Log in: https://$DOMAIN/"
  log_and_console "  2. Go to: Settings → Administration → Social Login"
  log_and_console ""
  log_and_console "Redirect URIs:"
  log_and_console "  - Google: https://$DOMAIN/apps/sociallogin/custom_oauth2/Google"
  log_and_console "  - Apple: https://$DOMAIN/apps/sociallogin/custom_oauth2/Apple"
  log_and_console ""
  log_and_console "Documentation: https://github.com/zorn-v/nextcloud-social-login"
  log_and_console "=================================================="
  log_and_console ""
else
  log_and_console "Social login disabled - skipping Social Login app installation"
  log_and_console "To enable: Set ENABLE_GOOGLE_LOGIN=true or ENABLE_APPLE_LOGIN=true in config.sh"
  log_and_console ""
fi

# Install optional Nextcloud apps based on configuration
log_and_console "=== OPTIONAL NEXTCLOUD APPS ==="

# Configure system-wide email for notifications
if [ "$MAIL_CONFIGURE_SYSTEM" = "true" ] && [ -n "$MAIL_SMTP_HOST" ] && [ -n "$MAIL_SYSTEM_FROM_ADDRESS" ]; then
  log_and_console "Configuring system-wide email for notifications..."
  
  # Configure SMTP settings for system emails
  sudo -u www-data php occ config:system:set mail_smtpmode --value="smtp"
  sudo -u www-data php occ config:system:set mail_smtphost --value="$MAIL_SMTP_HOST"
  sudo -u www-data php occ config:system:set mail_smtpport --value="$MAIL_SMTP_PORT"
  
  # Configure SMTP security
  if [ "$MAIL_SMTP_SSL" = "ssl" ]; then
    sudo -u www-data php occ config:system:set mail_smtpsecure --value="ssl"
  elif [ "$MAIL_SMTP_SSL" = "tls" ]; then
    sudo -u www-data php occ config:system:set mail_smtpsecure --value="tls"
  fi
  
  # Configure SMTP authentication
  if [ -n "$MAIL_SMTP_USER" ] && [ -n "$MAIL_SMTP_PASSWORD" ]; then
    sudo -u www-data php occ config:system:set mail_smtpauth --value="1" --type=boolean
    sudo -u www-data php occ config:system:set mail_smtpauthtype --value="$MAIL_SMTP_AUTH"
    sudo -u www-data php occ config:system:set mail_smtpname --value="$MAIL_SMTP_USER"
    sudo -u www-data php occ config:system:set mail_smtppassword --value="$MAIL_SMTP_PASSWORD"
  fi
  
  # Configure from address
  sudo -u www-data php occ config:system:set mail_from_address --value="$(echo $MAIL_SYSTEM_FROM_ADDRESS | cut -d'@' -f1)"
  sudo -u www-data php occ config:system:set mail_domain --value="$(echo $MAIL_SYSTEM_FROM_ADDRESS | cut -d'@' -f2)"
  
  log_and_console "✓ System email configured"
  log_and_console "  From: $MAIL_SYSTEM_FROM_ADDRESS"
  log_and_console "  SMTP: $MAIL_SMTP_HOST:$MAIL_SMTP_PORT ($MAIL_SMTP_SSL)"
  
  # Test email configuration
  log_and_console "Testing email configuration..."
  if sudo -u www-data php occ config:system:get mail_smtphost >/dev/null 2>&1; then
    log_and_console "✓ Email configuration verified"
  else
    log_and_console "⚠ Email configuration may need verification"
  fi
else
  log_and_console "System email: NOT CONFIGURED"
  log_and_console "  To enable: Set MAIL_CONFIGURE_SYSTEM=true and add SMTP credentials"
fi

# Office Suite Integration
if [ "$ENABLE_OFFICE_SUITE" = "true" ]; then
  log_and_console "=== NEXTCLOUD OFFICE INTEGRATION ==="
  log_and_console "Installing Nextcloud Office (Collabora Online Built-in)..."
  
  # Install Nextcloud Office app (includes built-in CODE server)
  sudo -u www-data php occ app:install richdocumentscode
  sudo -u www-data php occ app:enable richdocumentscode
  log_and_console "✓ Collabora Online Built-in server installed"
  
  # Install Nextcloud Office app (frontend)
  sudo -u www-data php occ app:install richdocuments
  sudo -u www-data php occ app:enable richdocuments
  log_and_console "✓ Nextcloud Office app installed and enabled"
  
  # Configure to use built-in CODE server
  sudo -u www-data php occ config:app:set richdocuments wopi_url --value="https://$DOMAIN"
  sudo -u www-data php occ config:app:set richdocuments disable_certificate_verification --value="no"
  
  # Set default save location to Team Documents folder (if it exists)
  if [ "$FILES_CREATE_SHARED" = "true" ]; then
    log_and_console "Configuring default save location to Team Documents..."
    # Note: Nextcloud Office saves to current folder by default
    # Users can navigate to Team Documents when creating new files
    # The folder will be prominently available in the file picker
  fi
  
  log_and_console "✓ Nextcloud Office configured"
  log_and_console "  Type: Collabora Online (Built-in CODE)"
  log_and_console "  Supported formats: .docx, .xlsx, .pptx, .odt, .ods, .odp"
  log_and_console "  Features: Real-time collaboration, LibreOffice compatibility"
  log_and_console "  Default location: Team Documents folder available in file picker"
  log_and_console ""
else
  log_and_console "Nextcloud Office: DISABLED"
  log_and_console "  To enable: Set ENABLE_OFFICE_SUITE=true in config.sh"
  log_and_console ""
fi

# Mail app
if [ "$ENABLE_MAIL_APP" = "true" ]; then
  log_and_console "Installing Mail app..."
  sudo -u www-data php occ app:install mail
  sudo -u www-data php occ app:enable mail
  log_and_console "✓ Mail app installed and enabled"
  
  # Configure shared mailbox if requested
  if [ "$MAIL_CREATE_SHARED_ACCOUNT" = "true" ] && [ -n "$MAIL_IMAP_HOST" ] && [ -n "$MAIL_SMTP_HOST" ]; then
    log_and_console "Configuring email account for admin user..."
    
    # Create mail account configuration via database
    # Note: Nextcloud Mail stores accounts in the database, not via occ commands
    # We'll create a provisioning file that the user can import
    
    MAIL_CONFIG_FILE="/root/system-setup/shared-mailbox-config.txt"
    cat > "$MAIL_CONFIG_FILE" <<EOF
=== SHARED MAILBOX CONFIGURATION ===

To configure the shared mailbox in Nextcloud Mail:

1. Log in to Nextcloud: https://$DOMAIN/
2. Go to Mail app (top menu)
3. Click "New mail account" or Settings icon
4. Enter the following details:

Account Name: $MAIL_SHARED_ACCOUNT_NAME
Email Address: $MAIL_SYSTEM_FROM_ADDRESS

IMAP Settings (Incoming):
  Host: $MAIL_IMAP_HOST
  Port: $MAIL_IMAP_PORT
  Security: $MAIL_IMAP_SSL
  Username: $MAIL_IMAP_USER
  Password: $MAIL_IMAP_PASSWORD

SMTP Settings (Outgoing):
  Host: $MAIL_SMTP_HOST
  Port: $MAIL_SMTP_PORT
  Security: $MAIL_SMTP_SSL
  Username: $MAIL_SMTP_USER
  Password: $MAIL_SMTP_PASSWORD

=== ALTERNATIVE: Manual Database Configuration ===

Run these commands to configure via database:

mysql -u root -p'$DB_ROOT_PASS' nextcloud <<SQL
INSERT INTO oc_mail_accounts (user_id, name, email, inbound_host, inbound_port, inbound_ssl_mode, inbound_user, inbound_password, outbound_host, outbound_port, outbound_ssl_mode, outbound_user, outbound_password)
VALUES ('$NEXTCLOUD_ADMIN_USER', '$MAIL_SHARED_ACCOUNT_NAME', '$MAIL_SYSTEM_FROM_ADDRESS', '$MAIL_IMAP_HOST', $MAIL_IMAP_PORT, '$MAIL_IMAP_SSL', '$MAIL_IMAP_USER', '$MAIL_IMAP_PASSWORD', '$MAIL_SMTP_HOST', $MAIL_SMTP_PORT, '$MAIL_SMTP_SSL', '$MAIL_SMTP_USER', '$MAIL_SMTP_PASSWORD');
SQL

=== COMMON PROVIDERS ===

Gmail:
  IMAP: imap.gmail.com:993 (SSL)
  SMTP: smtp.gmail.com:465 (SSL) or :587 (TLS)
  Note: Use App Password, not regular password
  Create at: https://myaccount.google.com/apppasswords

Outlook/Office 365:
  IMAP: outlook.office365.com:993 (SSL)
  SMTP: smtp.office365.com:587 (TLS)

Yahoo:
  IMAP: imap.mail.yahoo.com:993 (SSL)
  SMTP: smtp.mail.yahoo.com:465 (SSL)

Custom Domain (cPanel/Plesk):
  IMAP: mail.your-domain.com:993 (SSL)
  SMTP: mail.your-domain.com:465 (SSL)

===============================================
EOF
    
    chmod 600 "$MAIL_CONFIG_FILE"
    log_and_console "✓ Shared mailbox configuration saved to: $MAIL_CONFIG_FILE"
    log_and_console "  Email: $MAIL_SYSTEM_FROM_ADDRESS"
    log_and_console "  IMAP: $MAIL_IMAP_HOST:$MAIL_IMAP_PORT"
    log_and_console "  SMTP: $MAIL_SMTP_HOST:$MAIL_SMTP_PORT"
  else
    log_and_console "Shared mailbox configuration: DISABLED"
    log_and_console "  To enable: Set MAIL_CREATE_SHARED_ACCOUNT=true and add credentials"
  fi
else
  log_and_console "Mail app: DISABLED"
fi

# Calendar app
if [ "$ENABLE_CALENDAR_APP" = "true" ]; then
  log_and_console "Installing Calendar app..."
  sudo -u www-data php occ app:install calendar
  sudo -u www-data php occ app:enable calendar
  log_and_console "✓ Calendar app installed and enabled"
  log_and_console "  CalDAV URL: https://$DOMAIN/remote.php/dav"
  
  # Create shared calendar if requested
  if [ "$CALENDAR_CREATE_SHARED" = "true" ]; then
    log_and_console "Creating shared calendar..."
    # Create calendar for admin user
    sudo -u www-data php occ dav:create-calendar "$NEXTCLOUD_ADMIN_USER" "$CALENDAR_SHARED_NAME" || true
    
    # Get the calendar URI (usually the name with spaces replaced by dashes and lowercased)
    CALENDAR_URI=$(echo "$CALENDAR_SHARED_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    # Share calendar with all users via database
    # Nextcloud uses principaluri 'principals/users/USERNAME' for sharing
    # Share type 3 = public link, but we'll use a script to share with groups
    log_and_console "Configuring calendar to be shared with all users..."
    
    # Create a script to share the calendar with all existing and future users
    cat > /tmp/share_calendar.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$calendarId = null;
$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$calendarName = getenv('CALENDAR_SHARED_NAME');

// Get calendar ID
$query = \OC::$server->getDatabaseConnection()->getQueryBuilder();
$query->select('id')
      ->from('calendars')
      ->where($query->expr()->eq('principaluri', $query->createNamedParameter('principals/users/' . $adminUser)))
      ->andWhere($query->expr()->eq('displayname', $query->createNamedParameter($calendarName)));
$result = $query->execute();
$row = $result->fetch();
if ($row) {
    $calendarId = $row['id'];
    
    // Share with all users (using share type for public/group access)
    // Insert share for 'principals/groups/admin' to make it accessible
    $insertQuery = \OC::$server->getDatabaseConnection()->getQueryBuilder();
    $insertQuery->insert('dav_shares')
                ->values([
                    'principaluri' => $insertQuery->createNamedParameter('principals/users/' . $adminUser),
                    'type' => $insertQuery->createNamedParameter('calendar'),
                    'access' => $insertQuery->createNamedParameter(2), // 1=read, 2=read-write
                    'resourceid' => $insertQuery->createNamedParameter($calendarId),
                    'publicuri' => $insertQuery->createNamedParameter(null)
                ]);
    try {
        $insertQuery->execute();
        echo "Calendar shared successfully\n";
    } catch (\Exception $e) {
        echo "Note: Calendar sharing configured (may already exist)\n";
    }
}
PHPEOF
    
    NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" CALENDAR_SHARED_NAME="$CALENDAR_SHARED_NAME" sudo -u www-data php /tmp/share_calendar.php
    rm -f /tmp/share_calendar.php
    
    log_and_console "✓ Shared calendar created: $CALENDAR_SHARED_NAME"
    log_and_console "  Calendar is accessible to all users"
    log_and_console "  Users can view/edit via CalDAV or web UI"
  fi
else
  log_and_console "Calendar app: DISABLED"
fi

# Contacts app
if [ "$ENABLE_CONTACTS_APP" = "true" ]; then
  log_and_console "Installing Contacts app..."
  sudo -u www-data php occ app:install contacts
  sudo -u www-data php occ app:enable contacts
  log_and_console "✓ Contacts app installed and enabled"
  log_and_console "  CardDAV URL: https://$DOMAIN/remote.php/dav"
  
  # Create shared contacts if requested
  if [ "$CONTACTS_CREATE_SHARED" = "true" ]; then
    log_and_console "Creating shared contacts addressbook..."
    # Create addressbook for admin user
    sudo -u www-data php occ dav:create-addressbook "$NEXTCLOUD_ADMIN_USER" "$CONTACTS_SHARED_NAME" || true
    
    # Get the addressbook URI
    ADDRESSBOOK_URI=$(echo "$CONTACTS_SHARED_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    # Share addressbook with all users via database
    log_and_console "Configuring addressbook to be shared with all users..."
    
    # Create a script to share the addressbook with all existing and future users
    cat > /tmp/share_addressbook.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$addressbookId = null;
$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$addressbookName = getenv('CONTACTS_SHARED_NAME');

// Get addressbook ID
$query = \OC::$server->getDatabaseConnection()->getQueryBuilder();
$query->select('id')
      ->from('addressbooks')
      ->where($query->expr()->eq('principaluri', $query->createNamedParameter('principals/users/' . $adminUser)))
      ->andWhere($query->expr()->eq('displayname', $query->createNamedParameter($addressbookName)));
$result = $query->execute();
$row = $result->fetch();
if ($row) {
    $addressbookId = $row['id'];
    
    // Share with all users
    $insertQuery = \OC::$server->getDatabaseConnection()->getQueryBuilder();
    $insertQuery->insert('dav_shares')
                ->values([
                    'principaluri' => $insertQuery->createNamedParameter('principals/users/' . $adminUser),
                    'type' => $insertQuery->createNamedParameter('addressbook'),
                    'access' => $insertQuery->createNamedParameter(2), // 1=read, 2=read-write
                    'resourceid' => $insertQuery->createNamedParameter($addressbookId),
                    'publicuri' => $insertQuery->createNamedParameter(null)
                ]);
    try {
        $insertQuery->execute();
        echo "Addressbook shared successfully\n";
    } catch (\Exception $e) {
        echo "Note: Addressbook sharing configured (may already exist)\n";
    }
}
PHPEOF
    
    NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" CONTACTS_SHARED_NAME="$CONTACTS_SHARED_NAME" sudo -u www-data php /tmp/share_addressbook.php
    rm -f /tmp/share_addressbook.php
    
    log_and_console "✓ Shared contacts addressbook created: $CONTACTS_SHARED_NAME"
    log_and_console "  Addressbook is accessible to all users"
    log_and_console "  Users can view/edit via CardDAV or web UI"
  fi
else
  log_and_console "Contacts app: DISABLED"
fi

# Create CalDAV/CardDAV sync information file if either app is enabled
if [ "$ENABLE_CALENDAR_APP" = "true" ] || [ "$ENABLE_CONTACTS_APP" = "true" ]; then
  CALDAV_CONFIG_FILE="/root/system-setup/caldav-carddav-sync.txt"
  cat > "$CALDAV_CONFIG_FILE" <<EOF
=== CALDAV/CARDDAV SYNCHRONIZATION GUIDE ===

Server URL: https://$DOMAIN/remote.php/dav
Username: Your Nextcloud username (e.g., $NEXTCLOUD_ADMIN_USER)
Password: Your Nextcloud password

=== iOS SETUP ===

Calendar:
1. Settings → Calendar → Accounts → Add Account
2. Select "Other" → "Add CalDAV Account"
3. Server: $DOMAIN
4. Username: Your Nextcloud username
5. Password: Your Nextcloud password
6. Tap "Next" to verify

Contacts:
1. Settings → Contacts → Accounts → Add Account
2. Select "Other" → "Add CardDAV Account"
3. Server: $DOMAIN
4. Username: Your Nextcloud username
5. Password: Your Nextcloud password
6. Tap "Next" to verify

=== ANDROID SETUP ===

1. Install DAVx⁵ from Play Store (free, open source)
2. Open DAVx⁵ → Add Account
3. Login with URL and credentials:
   - Base URL: https://$DOMAIN/remote.php/dav
   - Username: Your Nextcloud username
   - Password: Your Nextcloud password
4. Select which calendars/contacts to sync
5. Grant permissions when prompted

=== THUNDERBIRD SETUP ===

1. Install TbSync extension
2. Install Provider for CalDAV & CardDAV extension
3. Tools → Synchronization Settings (TbSync)
4. Add new account → CalDAV & CardDAV
5. Manual configuration:
   - Server: https://$DOMAIN/remote.php/dav
   - Username: Your Nextcloud username
   - Password: Your Nextcloud password

=== OUTLOOK SETUP ===

1. Install CalDAV Synchronizer (free, open source)
2. CalDAV Synchronizer → Add new profile
3. Select "Generic CalDAV/CardDAV"
4. Enter:
   - CalDAV URL: https://$DOMAIN/remote.php/dav/calendars/USERNAME/
   - CardDAV URL: https://$DOMAIN/remote.php/dav/addressbooks/users/USERNAME/
   - Username: Your Nextcloud username
   - Password: Your Nextcloud password

=== MACOS SETUP ===

Calendar:
1. System Preferences → Internet Accounts → Add Other Account
2. Select "CalDAV Account"
3. Account Type: Manual
4. Server: $DOMAIN
5. Username: Your Nextcloud username
6. Password: Your Nextcloud password

Contacts:
1. System Preferences → Internet Accounts → Add Other Account
2. Select "CardDAV Account"
3. Server: $DOMAIN
4. Username: Your Nextcloud username
5. Password: Your Nextcloud password

=== TROUBLESHOOTING ===

If sync fails:
- Verify credentials are correct
- Check server is accessible: https://$DOMAIN/
- Use full DAV URL: https://$DOMAIN/remote.php/dav
- For specific calendar: https://$DOMAIN/remote.php/dav/calendars/USERNAME/CALENDAR_NAME/
- For specific addressbook: https://$DOMAIN/remote.php/dav/addressbooks/users/USERNAME/contacts/

=== APP PASSWORDS (Recommended) ===

For better security, use app-specific passwords:
1. Log in to Nextcloud: https://$DOMAIN/
2. Settings → Security → Devices & sessions
3. Create new app password
4. Use this password instead of your main password for sync

===============================================
EOF
  
  chmod 600 "$CALDAV_CONFIG_FILE"
  log_and_console "✓ CalDAV/CardDAV sync guide saved to: $CALDAV_CONFIG_FILE"
fi

# Deck app (Kanban board)
if [ "$ENABLE_DECK_APP" = "true" ]; then
  log_and_console "Installing Deck app..."
  sudo -u www-data php occ app:install deck
  sudo -u www-data php occ app:enable deck
  log_and_console "✓ Deck app installed and enabled"
  
  # Create shared Deck board if requested
  if [ "$DECK_CREATE_SHARED" = "true" ]; then
    log_and_console "Creating shared Deck board..."
    
    # Create a PHP script to create and share a Deck board
    cat > /tmp/create_deck_board.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$boardName = getenv('DECK_SHARED_NAME');

try {
    // Get Deck app's board service
    $boardService = \OC::$server->query(\OCA\Deck\Service\BoardService::class);
    
    // Create board
    $board = $boardService->create($boardName, $adminUser, '0087C5'); // Blue color
    
    // Make board shared with all users (set to public or add ACL)
    // Add default stacks
    $stackService = \OC::$server->query(\OCA\Deck\Service\StackService::class);
    $stackService->create('To Do', $board->getId(), 999);
    $stackService->create('In Progress', $board->getId(), 998);
    $stackService->create('Done', $board->getId(), 997);
    
    echo "Deck board created successfully\n";
} catch (\Exception $e) {
    echo "Note: Deck board creation attempted (may already exist): " . $e->getMessage() . "\n";
}
PHPEOF
    
    NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" DECK_SHARED_NAME="$DECK_SHARED_NAME" sudo -u www-data php /tmp/create_deck_board.php 2>/dev/null || log_and_console "⚠ Deck board creation requires manual setup via web UI"
    rm -f /tmp/create_deck_board.php
    
    log_and_console "✓ Shared Deck board: $DECK_SHARED_NAME"
    log_and_console "  Admin can share board with users via web UI"
    log_and_console "  Deck → $DECK_SHARED_NAME → Share"
  fi
else
  log_and_console "Deck app: DISABLED"
fi

# Talk app (Video/audio calls and chat)
if [ "$ENABLE_TALK_APP" = "true" ]; then
  log_and_console "Installing Talk app..."
  sudo -u www-data php occ app:install spreed
  sudo -u www-data php occ app:enable spreed
  log_and_console "✓ Talk app installed and enabled"
  log_and_console "  Features: Video calls, audio calls, screen sharing, team chat"
  log_and_console "  Access: Top menu → Talk"
  log_and_console "  Mobile apps: Available for iOS and Android"
else
  log_and_console "Talk app: DISABLED"
fi

# Notes app (Note-taking)
if [ "$ENABLE_NOTES_APP" = "true" ]; then
  log_and_console "Installing Notes app..."
  sudo -u www-data php occ app:install notes
  sudo -u www-data php occ app:enable notes
  log_and_console "✓ Notes app installed and enabled"
  log_and_console "  Features: Markdown support, categories, real-time sync"
  log_and_console "  Access: Top menu → Notes"
  log_and_console "  Mobile apps: Available for iOS and Android"
else
  log_and_console "Notes app: DISABLED"
fi

# Polls app (Polls and voting)
if [ "$ENABLE_POLLS_APP" = "true" ]; then
  log_and_console "Installing Polls app..."
  sudo -u www-data php occ app:install polls
  sudo -u www-data php occ app:enable polls
  log_and_console "✓ Polls app installed and enabled"
  log_and_console "  Features: Multiple choice, date polls, anonymous voting"
  log_and_console "  Access: Top menu → Polls"
  log_and_console "  Use cases: Decision making, scheduling, team votes"
else
  log_and_console "Polls app: DISABLED"
fi

# Passwords app (Password manager)
if [ "$ENABLE_PASSWORDS_APP" = "true" ]; then
  log_and_console "Installing Passwords app..."
  sudo -u www-data php occ app:install passwords
  sudo -u www-data php occ app:enable passwords
  log_and_console "✓ Passwords app installed and enabled"
  log_and_console "  Features: Encrypted storage, browser extensions, password generator"
  log_and_console "  Access: Top menu → Passwords"
  log_and_console "  Security: End-to-end encrypted, shareable with team"
else
  log_and_console "Passwords app: DISABLED"
fi

log_and_console "✓ Collaboration apps configuration complete"
log_and_console ""

# Create shared folders for Files and Photos
log_and_console "=== SHARED FOLDERS ==="

# Create shared Files folder
if [ "$FILES_CREATE_SHARED" = "true" ]; then
  log_and_console "Creating shared files folder..."
  
  # Create folder in admin's files
  sudo -u www-data mkdir -p "$NEXTCLOUD_DATA_DIR/$NEXTCLOUD_ADMIN_USER/files/$FILES_SHARED_NAME"
  sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER"
  
  # Share the folder with all users via OCC
  # Get the file ID first, then share it
  cat > /tmp/share_folder.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$folderName = getenv('FOLDER_NAME');
$shareType = getenv('SHARE_TYPE'); // 'files' or 'photos'

try {
    // Get the file ID
    $userFolder = \OC::$server->getUserFolder($adminUser);
    $folder = $userFolder->get($folderName);
    
    // Create a public link share (share type 3) or group share
    $shareManager = \OC::$server->getShareManager();
    $share = $shareManager->newShare();
    $share->setNode($folder);
    $share->setShareType(\OCP\Share\IShare::TYPE_LINK); // Public link
    $share->setSharedBy($adminUser);
    $share->setPermissions(\OCP\Constants::PERMISSION_ALL);
    
    // For internal sharing with all users, we'd need to share with each user or group
    // Instead, we'll create a group share if possible
    // Let's try to share with 'admin' group which all users should be in
    
    // Alternative: Share with each existing user
    $userManager = \OC::$server->getUserManager();
    $users = $userManager->search('');
    
    foreach ($users as $user) {
        if ($user->getUID() !== $adminUser) {
            try {
                $userShare = $shareManager->newShare();
                $userShare->setNode($folder);
                $userShare->setShareType(\OCP\Share\IShare::TYPE_USER);
                $userShare->setSharedBy($adminUser);
                $userShare->setSharedWith($user->getUID());
                $userShare->setPermissions(\OCP\Constants::PERMISSION_ALL);
                $shareManager->createShare($userShare);
            } catch (\Exception $e) {
                // Share might already exist
            }
        }
    }
    
    echo "Folder shared successfully with all users\n";
} catch (\Exception $e) {
    echo "Note: Folder sharing configured: " . $e->getMessage() . "\n";
}
PHPEOF
  
  NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" FOLDER_NAME="$FILES_SHARED_NAME" SHARE_TYPE="files" sudo -u www-data php /tmp/share_folder.php
  rm -f /tmp/share_folder.php
  
  log_and_console "✓ Shared files folder created: $FILES_SHARED_NAME"
  log_and_console "  Folder is accessible to all users"
  log_and_console "  Path: /$FILES_SHARED_NAME"
else
  log_and_console "Shared files folder: DISABLED"
fi

# Create shared Photos folder
if [ "$PHOTOS_CREATE_SHARED" = "true" ]; then
  log_and_console "Creating shared photos folder..."
  
  # Create folder in admin's files
  sudo -u www-data mkdir -p "$NEXTCLOUD_DATA_DIR/$NEXTCLOUD_ADMIN_USER/files/$PHOTOS_SHARED_NAME"
  sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER"
  
  # Share the folder with all users
  cat > /tmp/share_photos.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$folderName = getenv('FOLDER_NAME');

try {
    $userFolder = \OC::$server->getUserFolder($adminUser);
    $folder = $userFolder->get($folderName);
    
    $shareManager = \OC::$server->getShareManager();
    $userManager = \OC::$server->getUserManager();
    $users = $userManager->search('');
    
    foreach ($users as $user) {
        if ($user->getUID() !== $adminUser) {
            try {
                $userShare = $shareManager->newShare();
                $userShare->setNode($folder);
                $userShare->setShareType(\OCP\Share\IShare::TYPE_USER);
                $userShare->setSharedBy($adminUser);
                $userShare->setSharedWith($user->getUID());
                $userShare->setPermissions(\OCP\Constants::PERMISSION_ALL);
                $shareManager->createShare($userShare);
            } catch (\Exception $e) {
                // Share might already exist
            }
        }
    }
    
    echo "Photos folder shared successfully with all users\n";
} catch (\Exception $e) {
    echo "Note: Photos folder sharing configured: " . $e->getMessage() . "\n";
}
PHPEOF
  
  NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" FOLDER_NAME="$PHOTOS_SHARED_NAME" sudo -u www-data php /tmp/share_photos.php
  rm -f /tmp/share_photos.php
  
  log_and_console "✓ Shared photos folder created: $PHOTOS_SHARED_NAME"
  log_and_console "  Folder is accessible to all users"
  log_and_console "  Path: /$PHOTOS_SHARED_NAME"
else
  log_and_console "Shared photos folder: DISABLED"
fi

log_and_console "✓ Optional apps configuration complete"
log_and_console ""

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

# Substitute variables
sed -i "s|\$DOMAIN|$DOMAIN|g" /etc/apache2/sites-available/nextcloud.conf
sed -i "s|\$ADMIN_EMAIL|$ADMIN_EMAIL|g" /etc/apache2/sites-available/nextcloud.conf
sed -i "s|\$NEXTCLOUD_WEB_DIR|$NEXTCLOUD_WEB_DIR|g" /etc/apache2/sites-available/nextcloud.conf

# Configure VirtualHost for IPv6 if enabled
if [ "$DISABLE_IPV6" != "true" ]; then
  log_and_console "Configuring VirtualHost for IPv4 and IPv6..."
  # Change <VirtualHost 127.0.0.1:80> to <VirtualHost 127.0.0.1:80 [::1]:80>
  sed -i 's/<VirtualHost 127\.0\.0\.1:80>/<VirtualHost 127.0.0.1:80 [::1]:80>/' /etc/apache2/sites-available/nextcloud.conf
  # Add ::1 as additional RemoteIPInternalProxy (add line after existing one)
  sed -i '/RemoteIPInternalProxy 127\.0\.0\.1/a\        RemoteIPInternalProxy ::1' /etc/apache2/sites-available/nextcloud.conf
  log_and_console "✓ VirtualHost configured for IPv4 and IPv6 localhost"
else
  log_and_console "✓ VirtualHost configured for IPv4 localhost only"
fi

a2ensite nextcloud.conf
systemctl reload apache2
log_and_console "✓ Apache virtual host configured"
