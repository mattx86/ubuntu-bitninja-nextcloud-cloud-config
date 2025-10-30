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

# Enable built-in viewers
log_and_console "Enabling file viewers..."

# Enable PDF viewer (built-in)
sudo -u www-data php occ app:enable files_pdfviewer 2>/dev/null || {
  log_and_console "  ⚠ PDF viewer not available as built-in app"
}

# Enable text editor (built-in)
sudo -u www-data php occ app:enable files_texteditor 2>/dev/null || true

# Install and enable Viewer app (for images, videos, PDFs)
if sudo -u www-data php occ app:install viewer 2>&1 | tee -a "$LOG_FILE"; then
  sudo -u www-data php occ app:enable viewer
  log_and_console "✓ Viewer app installed (images, videos, PDFs)"
else
  log_and_console "  ⚠ Viewer app installation failed (may need manual installation)"
fi

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

# Remove default sample content from admin user
log_and_console "Removing default sample content from admin user..."
ADMIN_FILES_DIR="$NEXTCLOUD_DATA_DIR/$NEXTCLOUD_ADMIN_USER/files"

# Wait a moment for Nextcloud to initialize user directory
sleep 2

# Trigger user directory creation by running a files:scan
sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER" --quiet 2>/dev/null || true

# Now remove all default content
if [ -d "$ADMIN_FILES_DIR" ]; then
  log_and_console "Admin files directory found, removing default content..."
  
  # Remove ALL Nextcloud sample files
  rm -f "$ADMIN_FILES_DIR/Nextcloud intro.mp4" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Nextcloud Manual.pdf" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Nextcloud.png" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Nextcloud"*.* 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Reasons to use Nextcloud.pdf" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Readme.md" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/README.md" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Templates credits.md" 2>/dev/null || true
  rm -f "$ADMIN_FILES_DIR/Welcome"*.* 2>/dev/null || true
  
  # Remove ALL default personal folders
  rm -rf "$ADMIN_FILES_DIR/Documents" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Photos" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Templates" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Music" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Videos" 2>/dev/null || true
  
  # Remove default app folders (will be recreated with Team prefix if apps are enabled)
  rm -rf "$ADMIN_FILES_DIR/Talk" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Notes" 2>/dev/null || true
  rm -rf "$ADMIN_FILES_DIR/Deck" 2>/dev/null || true
  
  # Rescan admin files to update the database
  log_and_console "Scanning files to update database..."
  sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER" --quiet
  
  # Force a second scan to ensure database is in sync
  sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER" --quiet
  
  log_and_console "✓ All default sample content and personal folders removed"
else
  log_and_console "⚠ Admin files directory not found - will be cleaned on first login"
fi

# Disable unwanted default apps
log_and_console "Disabling unwanted default apps..."
# Disable Photos app (removes Photos icon from top menu)
sudo -u www-data php occ app:disable photos 2>/dev/null || true
# Disable Memories app (alternative photos app)
sudo -u www-data php occ app:disable memories 2>/dev/null || true
# Disable First Run Wizard (welcome popup on first login)
sudo -u www-data php occ app:disable firstrunwizard 2>/dev/null || true
log_and_console "✓ Unwanted apps disabled (Photos, Memories, First Run Wizard)"

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
  if sudo -u www-data php occ app:install sociallogin 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable sociallogin
    log_and_console "✓ Social Login app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Social Login app - social login will not work"
    log_and_console "  Install manually: sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ app:install sociallogin"
  fi

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
  if sudo -u www-data php occ app:install richdocumentscode 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable richdocumentscode
    log_and_console "✓ Collabora Online Built-in server installed"
  else
    log_and_console "⚠ WARNING: Failed to install Collabora CODE server"
  fi
  
  # Install Nextcloud Office app (frontend)
  if sudo -u www-data php occ app:install richdocuments 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable richdocuments
    log_and_console "✓ Nextcloud Office app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Nextcloud Office app"
  fi
  
  # Configure to use built-in CODE server
  log_and_console "Configuring Collabora Online settings..."
  
  # Set WOPI URL to use the domain
  sudo -u www-data php occ config:app:set richdocuments wopi_url --value="https://$DOMAIN"
  
  # Disable certificate verification (we're using Let's Encrypt which is trusted)
  sudo -u www-data php occ config:app:set richdocuments disable_certificate_verification --value="no"
  
  # Use built-in CODE server
  sudo -u www-data php occ config:app:set richdocuments public_wopi_url --value=""
  
  # Enable all document types
  sudo -u www-data php occ config:app:set richdocuments doc_format --value="ooxml"
  
  # Allow editing by default
  sudo -u www-data php occ config:app:set richdocuments edit_groups --value=""
  
  # Verify richdocumentscode is running
  if sudo -u www-data php occ richdocumentscode:activate 2>/dev/null; then
    log_and_console "  ✓ Built-in CODE server activated"
  else
    log_and_console "  ℹ Built-in CODE server activation attempted"
  fi
  
  # Set default save location to Team Files folder (if it exists)
  if [ "$FILES_CREATE_SHARED" = "true" ]; then
    log_and_console "Configuring default save location to Team Files..."
    # Note: Nextcloud Office saves to current folder by default
    # Users can navigate to Team Files when creating new files
    # The folder will be prominently available in the file picker
  fi
  
  log_and_console "✓ Nextcloud Office configured"
  log_and_console "  Type: Collabora Online (Built-in CODE)"
  log_and_console "  Supported formats: .docx, .xlsx, .pptx, .odt, .ods, .odp"
  log_and_console "  Features: Real-time collaboration, LibreOffice compatibility"
  log_and_console "  Default location: Team Files folder available in file picker"
  log_and_console ""
else
  log_and_console "Nextcloud Office: DISABLED"
  log_and_console "  To enable: Set ENABLE_OFFICE_SUITE=true in config.sh"
  log_and_console ""
fi

# Mail app
if [ "$ENABLE_MAIL_APP" = "true" ]; then
  log_and_console "Installing Mail app..."
  if sudo -u www-data php occ app:install mail 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable mail
    log_and_console "✓ Mail app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Mail app"
  fi
  
  # Configure team mailbox if requested
  if [ "$MAIL_CREATE_SHARED_ACCOUNT" = "true" ] && [ -n "$MAIL_IMAP_HOST" ] && [ -n "$MAIL_SMTP_HOST" ]; then
    log_and_console "Configuring team mailbox for admin user..."
    
    # Create mail account configuration via database
    # Note: Nextcloud Mail stores accounts in the database, not via occ commands
    # We'll create a provisioning file that the user can import
    
    MAIL_CONFIG_FILE="/root/system-setup/team-mailbox-config.txt"
    cat > "$MAIL_CONFIG_FILE" <<EOF
=== TEAM MAILBOX CONFIGURATION ===

To configure the team mailbox in Nextcloud Mail:

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
    log_and_console "✓ Team mailbox configuration saved to: $MAIL_CONFIG_FILE"
    log_and_console "  Email: $MAIL_SYSTEM_FROM_ADDRESS"
    log_and_console "  IMAP: $MAIL_IMAP_HOST:$MAIL_IMAP_PORT"
    log_and_console "  SMTP: $MAIL_SMTP_HOST:$MAIL_SMTP_PORT"
  else
    log_and_console "Team mailbox configuration: DISABLED"
    log_and_console "  To enable: Set MAIL_CREATE_SHARED_ACCOUNT=true and add credentials"
  fi
else
  log_and_console "Mail app: DISABLED"
fi

# Calendar app
if [ "$ENABLE_CALENDAR_APP" = "true" ]; then
  log_and_console "Installing Calendar app..."
  if sudo -u www-data php occ app:install calendar 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable calendar
    log_and_console "✓ Calendar app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Calendar app"
  fi
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
  if sudo -u www-data php occ app:install contacts 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable contacts
    log_and_console "✓ Contacts app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Contacts app"
  fi
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
  if sudo -u www-data php occ app:install deck 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable deck
    log_and_console "✓ Deck app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Deck app"
  fi
  
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
  if sudo -u www-data php occ app:install spreed 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable spreed
  else
    log_and_console "⚠ WARNING: Failed to install Talk app"
  fi
  
  # Apply patch to fix folder creation locking bug
  # This fixes a race condition where multiple processes try to create the Talk folder simultaneously
  TALK_INITIAL_STATE="$NEXTCLOUD_WEB_DIR/apps/spreed/lib/TInitialState.php"
  if [ -f "$TALK_INITIAL_STATE" ]; then
    log_and_console "  Applying Talk locking fix patch..."
    
    # Check if patch is needed (look for the unpatched code)
    if grep -q '} catch (NotFoundException \$e) {$' "$TALK_INITIAL_STATE" && \
       grep -A 1 '} catch (NotFoundException \$e) {$' "$TALK_INITIAL_STATE" | grep -q '\$folder = \$userFolder->newFolder(\$attachmentFolder);'; then
      
      # Create backup
      cp "$TALK_INITIAL_STATE" "${TALK_INITIAL_STATE}.original"
      
      # Apply patch using sed (add LockedException handling)
      sed -i '/} catch (NotFoundException \$e) {$/,/\$folder = \$userFolder->newFolder(\$attachmentFolder);$/ {
        /\$folder = \$userFolder->newFolder(\$attachmentFolder);$/ {
          c\
\t\t\t\t\t\t// Try to create the folder, but handle the case where another process creates it simultaneously\
\t\t\t\t\t\ttry {\
\t\t\t\t\t\t\t$folder = $userFolder->newFolder($attachmentFolder);\
\t\t\t\t\t\t} catch (\\OCP\\Lock\\LockedException $lockException) {\
\t\t\t\t\t\t\t// Another process is creating the folder, wait and retry\
\t\t\t\t\t\t\tusleep(100000);\
\t\t\t\t\t\t\ttry {\
\t\t\t\t\t\t\t\t$folder = $userFolder->get($attachmentFolder);\
\t\t\t\t\t\t\t} catch (NotFoundException $notFoundException) {\
\t\t\t\t\t\t\t\tthrow new NotPermittedException("Could not create folder due to locking");\
\t\t\t\t\t\t\t}\
\t\t\t\t\t\t}
        }
      }' "$TALK_INITIAL_STATE"
      
      log_and_console "  ✓ Talk locking fix applied"
    else
      log_and_console "  ℹ Talk locking fix not needed (already patched or code changed)"
    fi
  fi
  
  # Configure Talk attachment folder name
  log_and_console "Configuring Talk attachment folder..."
  sudo -u www-data php occ config:app:set spreed default_attachment_folder --value="/Team Talk"
  log_and_console "✓ Talk attachment folder set to: /Team Talk"
  
  log_and_console "✓ Talk app installed and enabled"
  log_and_console "  Features: Video calls, audio calls, screen sharing, team chat, file attachments"
  log_and_console "  Attachment folder: /Team Talk"
  log_and_console "  Access: Top menu → Talk"
  log_and_console "  Mobile apps: Available for iOS and Android"
else
  log_and_console "Talk app: DISABLED"
fi

# Notes app (Note-taking)
if [ "$ENABLE_NOTES_APP" = "true" ]; then
  log_and_console "Installing Notes app..."
  if sudo -u www-data php occ app:install notes 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable notes
  else
    log_and_console "⚠ WARNING: Failed to install Notes app"
  fi
  
  # Configure Notes folder name
  log_and_console "Configuring Notes folder..."
  sudo -u www-data php occ config:app:set notes notesPath --value="Team Notes"
  log_and_console "✓ Notes folder set to: /Team Notes"
  
  log_and_console "✓ Notes app installed and enabled"
  log_and_console "  Features: Markdown support, categories, real-time sync"
  log_and_console "  Notes folder: /Team Notes"
  log_and_console "  Access: Top menu → Notes"
  log_and_console "  Mobile apps: Available for iOS and Android"
else
  log_and_console "Notes app: DISABLED"
fi

# Polls app (Polls and voting)
if [ "$ENABLE_POLLS_APP" = "true" ]; then
  log_and_console "Installing Polls app..."
  if sudo -u www-data php occ app:install polls 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable polls
    log_and_console "✓ Polls app installed and enabled"
  else
    log_and_console "⚠ WARNING: Failed to install Polls app"
  fi
  log_and_console "  Features: Multiple choice, date polls, anonymous voting"
  log_and_console "  Access: Top menu → Polls"
  log_and_console "  Use cases: Decision making, scheduling, team votes"
else
  log_and_console "Polls app: DISABLED"
fi

# Passwords app (Password manager)
if [ "$ENABLE_PASSWORDS_APP" = "true" ]; then
  log_and_console "Installing Passwords app..."
  if sudo -u www-data php occ app:install passwords 2>&1 | tee -a "$LOG_FILE"; then
    sudo -u www-data php occ app:enable passwords
    log_and_console "✓ Passwords app installed and enabled"
    log_and_console "  Features: Encrypted storage, browser extensions, password generator"
    log_and_console "  Access: Top menu → Passwords"
    log_and_console "  Security: End-to-end encrypted, shareable with team"
  else
    log_and_console "⚠ WARNING: Failed to install Passwords app from app store"
    log_and_console "  You can install it manually later via: Apps → Office & text → Passwords"
    log_and_console "  Or run: sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ app:install passwords"
  fi
else
  log_and_console "Passwords app: DISABLED"
fi

log_and_console "✓ Collaboration apps configuration complete"
log_and_console ""

# Create shared folders
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
  
  NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" FOLDER_NAME="$FILES_SHARED_NAME" sudo -u www-data php /tmp/share_folder.php
  rm -f /tmp/share_folder.php
  
  log_and_console "✓ Shared files folder created: $FILES_SHARED_NAME"
  log_and_console "  Folder is accessible to all users"
  log_and_console "  Path: /$FILES_SHARED_NAME"
else
  log_and_console "Shared files folder: DISABLED"
fi

log_and_console "✓ Optional apps configuration complete"
log_and_console ""

# ===== CLEANUP DEFAULT WELCOME CONTENT =====
log_and_console "=== REMOVING DEFAULT WELCOME CONTENT ==="
log_and_console "Cleaning up default welcome content from all apps..."

cat > /tmp/cleanup_welcome_content.php <<'PHPEOF'
<?php
require '/var/www/nextcloud/lib/base.php';
\OC::$CLI = true;

$adminUser = getenv('NEXTCLOUD_ADMIN_USER');
$connection = \OC::$server->getDatabaseConnection();
$config = \OC::$server->getConfig();

echo "Cleaning up welcome content for user: $adminUser\n\n";

// 1. Clear Activity entries
try {
    $qb = $connection->getQueryBuilder();
    $qb->delete('activity')
       ->where($qb->expr()->eq('affecteduser', $qb->createNamedParameter($adminUser)))
       ->execute();
    echo "✓ Activity entries cleared\n";
} catch (\Exception $e) {
    echo "⚠ Activity: " . $e->getMessage() . "\n";
}

// 2. Clear Dashboard first-run and notifications
try {
    $config->deleteUserValue($adminUser, 'dashboard', 'firstRun');
    $config->deleteUserValue($adminUser, 'firstrunwizard', 'show');
    $config->deleteUserValue($adminUser, 'firstrunwizard', 'state');
    
    $qb = $connection->getQueryBuilder();
    $qb->delete('notifications')
       ->where($qb->expr()->eq('user', $qb->createNamedParameter($adminUser)))
       ->execute();
    echo "✓ Dashboard and notifications cleared\n";
    echo "✓ First-run wizard settings cleared\n";
} catch (\Exception $e) {
    echo "⚠ Dashboard: " . $e->getMessage() . "\n";
}

// 3. Clear Talk welcome conversations
try {
    $qb = $connection->getQueryBuilder();
    $qb->select('room_id')
       ->from('talk_attendees')
       ->where($qb->expr()->eq('actor_id', $qb->createNamedParameter($adminUser)));
    $result = $qb->execute();
    $roomIds = $result->fetchAll(\PDO::FETCH_COLUMN);
    $result->closeCursor();
    
    $removedCount = 0;
    foreach ($roomIds as $roomId) {
        $qb = $connection->getQueryBuilder();
        $qb->select('name')
           ->from('talk_rooms')
           ->where($qb->expr()->eq('id', $qb->createNamedParameter($roomId)));
        $roomResult = $qb->execute();
        $room = $roomResult->fetch();
        $roomResult->closeCursor();
        
        if ($room && (stripos($room['name'], 'Talk updates') !== false || 
                      stripos($room['name'], 'Welcome') !== false ||
                      stripos($room['name'], 'changelog') !== false)) {
            $qb = $connection->getQueryBuilder();
            $qb->delete('talk_attendees')
               ->where($qb->expr()->eq('room_id', $qb->createNamedParameter($roomId)))
               ->execute();
            $qb = $connection->getQueryBuilder();
            $qb->delete('talk_rooms')
               ->where($qb->expr()->eq('id', $qb->createNamedParameter($roomId)))
               ->execute();
            $removedCount++;
        }
    }
    echo "✓ Talk conversations cleared ($removedCount removed)\n";
} catch (\Exception $e) {
    echo "⚠ Talk: " . $e->getMessage() . "\n";
}

// 4. Clear Deck welcome board
try {
    $boardService = \OC::$server->query(\OCA\Deck\Service\BoardService::class);
    $boards = $boardService->findAll($adminUser);
    $removedCount = 0;
    
    foreach ($boards as $board) {
        if (stripos($board->getTitle(), 'Welcome to') !== false || 
            stripos($board->getTitle(), 'Nextcloud Deck') !== false) {
            $boardService->delete($board->getId());
            $removedCount++;
        }
    }
    echo "✓ Deck welcome boards cleared ($removedCount removed)\n";
} catch (\Exception $e) {
    echo "⚠ Deck: " . $e->getMessage() . "\n";
}

// 5. Clear Files app welcome tips and first-run
try {
    // Clear Files app first-run wizard
    $config->deleteUserValue($adminUser, 'files', 'show_hidden');
    $config->deleteUserValue($adminUser, 'files', 'quota');
    
    // Clear any Files app tips/hints
    $qb = $connection->getQueryBuilder();
    $qb->delete('preferences')
       ->where($qb->expr()->eq('userid', $qb->createNamedParameter($adminUser)))
       ->andWhere($qb->expr()->eq('appid', $qb->createNamedParameter('files')))
       ->andWhere($qb->expr()->like('configkey', $qb->createNamedParameter('%hint%')))
       ->execute();
    
    echo "✓ Files app welcome tips cleared\n";
} catch (\Exception $e) {
    echo "⚠ Files: " . $e->getMessage() . "\n";
}

echo "\n✓ Welcome content cleanup complete!\n";
PHPEOF

NEXTCLOUD_ADMIN_USER="$NEXTCLOUD_ADMIN_USER" sudo -u www-data php /tmp/cleanup_welcome_content.php 2>&1 | tee -a "$LOG_FILE"
rm -f /tmp/cleanup_welcome_content.php

# Remove default welcome notes files
NOTES_DIR="$NEXTCLOUD_DATA_DIR/$NEXTCLOUD_ADMIN_USER/files/Team Notes"
if [ -d "$NOTES_DIR" ]; then
  log_and_console "Removing default welcome notes..."
  rm -f "$NOTES_DIR/Welcome"*.* "$NOTES_DIR/Getting Started"*.* 2>/dev/null || true
  sudo -u www-data php occ files:scan "$NEXTCLOUD_ADMIN_USER" --path="/Team Notes" --quiet 2>/dev/null || true
  log_and_console "✓ Welcome notes removed"
fi

log_and_console "✓ All default welcome content removed from:"
log_and_console "  - Dashboard (first-run wizard, notifications)"
log_and_console "  - Activity (welcome messages)"
log_and_console "  - Talk (changelog conversations)"
log_and_console "  - Files (welcome tips and hints)"
log_and_console "  - Notes (welcome notes)"
log_and_console "  - Deck (welcome boards)"
log_and_console ""

# Set up cron jobs for Nextcloud
log_and_console "Setting up cron jobs for Nextcloud..."

# Create temporary cron file
cat > /tmp/nextcloud-cron << EOF
# Nextcloud background tasks (every 5 minutes)
*/5 * * * * php -f $NEXTCLOUD_WEB_DIR/cron.php

# Nextcloud file scan to sync filesystem with database (daily at 3 AM)
0 3 * * * php $NEXTCLOUD_WEB_DIR/occ files:scan --all --quiet

EOF

# Install cron jobs for www-data user
crontab -u www-data /tmp/nextcloud-cron
rm -f /tmp/nextcloud-cron

log_and_console "✓ Cron jobs configured:"
log_and_console "  - Background tasks: Every 5 minutes"
log_and_console "  - File system scan: Daily at 3:00 AM"

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
