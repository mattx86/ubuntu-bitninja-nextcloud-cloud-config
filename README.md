# Ubuntu + Nextcloud + BitNinja WAF 2.0 Cloud-Config

Copyright (c) 2025 Matt Smith - [MIT License](LICENSE.md)

## 📋 Overview

This cloud-config YAML provides a complete, production-ready installation of **Nextcloud** with **BitNinja WAF 2.0** on **Ubuntu 24.04 LTS**, following official documentation from both projects. Includes **automated SSL certificate acquisition** via Let's Encrypt with certbot.

### 🏗️ Architecture

**HTTPS Traffic Flow:**
```
External Client
    ↓ HTTPS (port 443)
UFW Firewall (allows only SERVER_IP:443)
    ↓
BitNinja SSL Terminating (0.0.0.0:443)
    ↓ Decrypts HTTPS, applies WAF rules
    ↓ Forwards decrypted HTTP traffic
Apache (127.0.0.1:80)
    ↓
Nextcloud
```

**Key Points:**
- BitNinja listens on **all interfaces (0.0.0.0:443)** for SSL termination
- UFW firewall restricts access to **SERVER_IP:443 only**
- Apache backend listens on **localhost only (127.0.0.1:80)** - HTTP only
- BitNinja internal ports (60415, 60418) bound to **127.0.0.1** for security
- All external HTTPS traffic passes through UFW → BitNinja WAF → Apache

### Stack Components
- **Web Server:** Apache 2.4 with mod_php (localhost only)
- **PHP Version:** 8.3 with all required + recommended modules
- **Database:** MariaDB 10.x with utf8mb4, SSL enabled
- **Caching:** Redis + APCu (localhost only)
- **Security:** BitNinja WAF 2.0, UFW firewall, fail2ban, IPv6 disabled
- **SSL:** Automated Let's Encrypt certificates via certbot (auto-renewal every 60 days)

---

## 🎯 Quick Start

### 1. Before Deployment

**⚠️ CRITICAL: SSH Key Requirement**

This configuration **disables password authentication** for SSH security. You MUST have an SSH key configured in your cloud provider BEFORE deployment, or you will be locked out of your server!

- Most cloud providers (Hetzner, DigitalOcean, AWS, etc.) allow you to add SSH keys during server creation
- If you don't have an SSH key, create one first: `ssh-keygen -t ed25519 -C "your_email@example.com"`
- Add your public key to your cloud provider's dashboard before deploying

**Required Changes:**

1. **Update configuration variables** in the config section of the YAML file:
   ```yaml
   # ===== SYSTEM CONFIGURATION =====
   export DOMAIN="your-domain.com"
   export ADMIN_EMAIL="admin@your-domain.com"
   export BITNINJA_LICENSE="YOUR_LICENSE_KEY"
   export TIMEZONE="UTC"
   
   # ===== MEMORY CONFIGURATION =====
   # For 2GB+ RAM systems, uncomment these and comment out 1GB settings:
   # export PHP_MEMORY_LIMIT="512M"        # Default: 256M
   # export MARIADB_BUFFER_POOL="1G"       # Default: 256M
   # export OPCACHE_MEMORY="128"           # Default: 64M
   
   # ===== DATABASE CONFIGURATION =====
   export DB_NAME="nextcloud"
   export DB_USER="nextcloud"
   # Passwords are auto-generated during setup and stored securely
   
   # ===== NEXTCLOUD CONFIGURATION =====
   export NEXTCLOUD_ADMIN_USER="admin"
   # Admin password is auto-generated during setup
   ```
   
   **Note:** Passwords are automatically generated during deployment and stored securely in `/root/system-setup/.passwords`. You don't need to set them manually.

2. **Get BitNinja license key:**
   - Free trial: [https://admin.bitninja.io](https://admin.bitninja.io)

### 2. Deploy

Upload to your cloud provider (Hetzner, AWS, DigitalOcean, etc.) as a cloud-config/user-data file.

### 3. After Deployment

#### 🎉 Cloud-Init Setup Complete!

**Installation Status:**
✅ All core services installed and running  
✅ BitNinja security features enabled  
✅ MariaDB security configuration applied  
✅ Apache configured for localhost-only operation  
✅ SSL certificates automatically obtained via Let's Encrypt  
✅ System requirements verified  
✅ Firewall configured (HTTP/HTTPS, SSH)

**Components Configured:**
- Apache 2.4 with PHP 8.3 (mod_php)
- MariaDB with optimized settings
- Redis + APCu caching
- BitNinja WAF 2.0 with SSL Terminating module (automatically configured)
- UFW firewall enabled
- Let's Encrypt SSL certificates with automatic renewal

**Critical Files Created:**
- Scripts Directory: `/root/system-setup/scripts/`
- Logs Directory: `/root/system-setup/logs/`
- Downloads Directory: `/root/system-setup/downloads/`
- Passwords File: `/root/system-setup/.passwords` (secure, 600 permissions)
- Configuration: `/root/system-setup/config.sh` (environment variables)

**Main Scripts Available:**
- System Verification: `/root/system-setup/scripts/_13_system_verification.sh`

#### 🔐 Generated Passwords

**IMPORTANT: Save these passwords immediately - they will not be displayed again!**

```bash
# View generated passwords
cat /root/system-setup/.passwords

# Password file location: /root/system-setup/.passwords (secure, 600 permissions)
```

**All passwords have been automatically generated and stored securely:**
- Database password: Auto-generated and stored
- Database root password: Auto-generated and stored  
- Nextcloud admin password: Auto-generated and stored

#### 📋 Immediate Steps

```bash
# 1. Get generated passwords (see above)
cat /root/system-setup/.passwords

# 2. Verify installation
/root/system-setup/scripts/_13_system_verification.sh

# 3. Check Nextcloud status
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ status

# 4. Review setup log
cat /root/system-setup/logs/deployment.log
   # Or view system verification log
   cat /root/system-setup/logs/system-verification.log
```

#### 🔐 Critical Security Steps

**1. Update Passwords (CRITICAL!)**
Before exposing to the internet, update passwords:

```bash
# a) Update database password in config.php (optional - already secure)
sudo nano $NEXTCLOUD_WEB_DIR/config/config.php
# Find 'dbpassword' and change from the generated password

# b) Update database user password in MariaDB (recommended)
sudo mysql
ALTER USER 'nextcloud'@'localhost' IDENTIFIED BY 'new_secure_password';
FLUSH PRIVILEGES;
exit;

# c) Change Nextcloud admin password (recommended)
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ user:resetpassword admin
```

**2. Verify SSL Certificate**
```bash
# Check if Let's Encrypt certificate was obtained
ls -la /etc/letsencrypt/live/$DOMAIN/

# Verify automatic renewal is configured
systemctl status certbot.timer
certbot renew --dry-run

# Check BitNinja SSL Terminating is using the certificate
bitninjacli --module=SslTerminating --status
```

**3. Configure BitNinja (if license key was not provided)**
```bash
# Manual installation (if needed)
curl https://get.bitninja.io/install.sh | sudo /bin/bash -s - --license_key=YOUR_LICENSE_KEY

# Verify BitNinja is running
systemctl status bitninja
bitninjacli --version

# Login to BitNinja dashboard: https://admin.bitninja.io
# - Review and customize protection rules as needed
# - Monitor security events and adjust settings
```

**4. Access Nextcloud**
After DNS propagation and SSL setup:
- Navigate to: `https://your-domain.com`
- Username: `admin`
- Password: The one you set in step 1c

**Note on DNS and SSL Acquisition:**
Point your domain's A record to the server IP **before** deployment for automatic SSL setup. During deployment:
1. DNS verification checks if your domain resolves to the server IP
2. If DNS is correct, Let's Encrypt certificate is automatically obtained
3. BitNinja SSL Terminating is configured to use the certificate
4. Auto-renewal is set up via certbot's systemd timer

If DNS is not configured at deployment time, the script will skip SSL acquisition and you can manually run it later:
```bash
# After configuring DNS, manually obtain SSL certificate
/root/system-setup/scripts/_7_ssl_certificate.sh
```

**How It Works:**
- Apache is configured to bind to `127.0.0.1:80` only (localhost)
- Certbot binds to `SERVER_IP:80` (public IP) for HTTP-01 challenges - no conflict
- No Apache downtime needed during certificate acquisition
- BitNinja SSL Terminating (port 443) receives certificates via CLI (`--add-cert`)
- Renewal hooks ensure BitNinja picks up renewed certificates every 60 days

#### 🔧 Post-Installation Configuration

**Nextcloud Setup:**
```bash
# Login to Nextcloud and complete:
# a) Go to Settings > Administration > Basic settings
#    - Configure email server for notifications
# b) Go to Settings > Administration > Overview
#    - Review security warnings and recommendations
#    - Run suggested commands if needed
# c) Verify background jobs (already configured via cron)
crontab -u www-data -l
```

**Security Hardening:**
```bash
# Configure regular backups
# Important directories:
# * /var/www/nextcloud/config/ (configuration)
# * /var/nextcloud-data/ (user data)
# * Database: mysqldump nextcloud > nextcloud_backup.sql

# Keep system updated
sudo apt update && sudo apt upgrade -y

# Monitor logs
sudo tail -f $NEXTCLOUD_WEB_DIR/data/nextcloud.log
sudo tail -f /var/log/apache2/nextcloud-error.log
sudo tail -f /var/log/syslog
```

**Nextcloud Optimization:**
- Install recommended apps from App Store:
  - Nextcloud Office (for document editing)
  - Calendar, Contacts, Mail (for groupware)
  - Talk (for video conferencing)
- Enable external storage if needed (already enabled via `occ app:enable files_external`)
- Performance monitoring: `sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ config:list`

#### 📁 Organized Directories

**System Setup Structure:**
- **Scripts:** `/root/system-setup/scripts/`
- **Logs:** `/root/system-setup/logs/`
- **Downloads:** `/root/system-setup/downloads/`
- **Passwords:** `/root/system-setup/.passwords`

**Setup Log Location:**
- **Deployment Log:** `/root/system-setup/logs/deployment.log`
- **System Verification:** `/root/system-setup/logs/system-verification.log`
- Review this log for detailed system requirements check results

#### 🔒 Security Recommendations

**After First Login:**
- Change all passwords for enhanced security
- Review fail2ban status: `fail2ban-client status`
- Monitor BitNinja WAF Pro dashboard for security events

**Next Steps Summary:**
1. Optional: Run `/root/system-setup/scripts/_13_system_verification.sh` to verify everything
2. Verify SSL certificate: `systemctl status certbot.timer` and `certbot renew --dry-run`
3. Change default passwords (see security steps above)
4. Access Nextcloud: `https://your-domain.com`

**SSL Certificate Management:**
- **Automatic Renewal:** Certbot's systemd timer runs twice daily and renews certificates within 30 days of expiration
- **Check Timer:** `systemctl list-timers certbot.timer`
- **Manual Renewal Test:** `certbot renew --dry-run`
- **Force Recollect (BitNinja):** `bitninjacli --module=SslTerminating --force-recollect && bitninjacli --module=SslTerminating --restart`

**Documentation Resources:**
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [BitNinja WAF 2.0 Documentation](https://doc.bitninja.io/docs/Modules/waf)
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)

---

## 🔧 Configuration Features

### 💾 Memory Configuration
The cloud-config includes optimized memory settings for different system sizes:

**1GB RAM System (Default):**
- PHP Memory Limit: 256MB
- MariaDB Buffer Pool: 256MB  
- OPcache Memory: 64MB
- Total Memory Usage: ~576MB + system overhead

**2GB RAM System:**
- PHP Memory Limit: 512MB
- MariaDB Buffer Pool: 1GB
- OPcache Memory: 128MB
- Total Memory Usage: ~1.64GB + system overhead

To use 2GB settings, uncomment the 2GB configuration lines in the config section and comment out the 1GB settings.

### ✅ BitNinja WAF 2.0 with SSL Terminating
- **WAF Protection:** Web application firewall with advanced threat detection
- **SSL Terminating Module:** Handles HTTPS traffic and forwards to Apache
- **Let's Encrypt Integration:** Automatic SSL certificate acquisition and renewal
- **Module Configuration:** All modules enabled by default except those in `disabledModules` array
- **Enabled Modules:** System, ConfigParser, DataProvider, SslTerminating, WAFManager, MalwareDetection, DosDetection, SenseLog, DefenseRobot (enabled by not being in disabledModules)
- **Disabled Modules (via config.php):** IpFilter, AntiFlood, AuditManager, CaptchaFtp, CaptchaHttp, CaptchaSmtp, MalwareScanner, OutboundHoneypot, Patcher, PortHoneypot, ProxyFilter, SandboxScanner, SenseWebHoneypot, Shogun, SiteProtection, SpamDetection, SqlScanner, TalkBack, WAF3, ProcessAnalysis
- **Firewall Management:** Completely disabled - UFW manages all firewall rules including DNAT
- **Automatic Cleanup:** Systemd service (`bitninja-remove-firewall-rules.service`) removes BitNinja iptables rules on every BitNinja restart

### ✅ Nextcloud (Official Docs Compliant)
- **Complete PHP Stack:** All required and recommended PHP 8.3 modules
- **Optimized Database:** MariaDB with utf8mb4, SSL, and performance tuning
- **Caching Layer:** Redis + APCu for optimal performance
- **Security Hardened:** Proper file permissions, fail2ban, firewall rules
- **Emoji Support:** MySQL 4-byte support enabled

### ✅ System Security
- **IPv6 Disabled:** System-wide IPv6 disablement for security
- **Service Binding:** All services bound to localhost only
- **Firewall Configuration:** UFW (IPv4-only) with SSH, HTTP (Let's Encrypt), and HTTPS
- **DNAT Management:** UFW manages DNAT rules (BitNinja firewall management disabled via IpFilter module)
- **Automatic Updates:** Unattended security updates enabled
- **System Hardening:** Disabled unnecessary services, secured shared memory

### ✅ Variable-Based Configuration
- **Centralized Settings:** All configuration in `/root/system-setup/config.sh`
- **No Hardcoded Values:** All paths and settings use variables
- **Easy Customization:** Modify settings in one place

---

## 📚 Scripts and Configuration Files

### 🔧 Deployment Scripts

All deployment scripts are automatically downloaded and executed during cloud-init. The comprehensive system verification is performed by `_13_system_verification.sh` after deployment is complete.

### ⚙️ Configuration Files

All configuration files are downloaded from GitHub during deployment:

| Config File | Purpose | GitHub URL |
|-------------|---------|------------|
| `50ubuntu-unattended-upgrades` | Automatic security updates (Ubuntu) | [`conf/50ubuntu-unattended-upgrades`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/50ubuntu-unattended-upgrades) |
| `fail2ban-jail.local` | fail2ban jail configuration | [`conf/fail2ban-jail.local`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/fail2ban-jail.local) |
| `fail2ban-nextcloud.conf` | fail2ban filter (monitors Nextcloud app login failures) | [`conf/fail2ban-nextcloud.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/fail2ban-nextcloud.conf) |
| `fail2ban-bitninja-waf.conf` | fail2ban filter (monitors BitNinja WAF detections) | [`conf/fail2ban-bitninja-waf.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/fail2ban-bitninja-waf.conf) |
| `fail2ban-bitninja-captcha.conf` | fail2ban filter (monitors BitNinja Captcha abuse - not used, CaptchaHttp disabled) | [`conf/fail2ban-bitninja-captcha.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/fail2ban-bitninja-captcha.conf) |
| `nextcloud-apache-vhost.conf` | Apache virtual host configuration | [`conf/nextcloud-apache-vhost.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/nextcloud-apache-vhost.conf) |
| `nextcloud-mariadb.cnf` | MariaDB optimization settings | [`conf/nextcloud-mariadb.cnf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/nextcloud-mariadb.cnf) |

---

## 🔐 Security Checklist

### Critical: Secure Passwords Generated

**Passwords are automatically generated during deployment:**

1. **View Generated Passwords**
   ```bash
   # All passwords are securely generated and saved here:
   cat /root/system-setup/.passwords
   ```

2. **Change Passwords After First Login** (Recommended)
   ```bash
   # Database password (optional - already secure)
   sudo nano $NEXTCLOUD_WEB_DIR/config/config.php
   
   # Nextcloud admin password (recommended)
   sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ user:resetpassword admin
   
   # MariaDB root password (recommended)
   sudo mysql_secure_installation
   ```

### Verify BitNinja WAF 2.0

```bash
# Check if installed and running
systemctl status bitninja
bitninjacli --version

# Check WAF 2.0 and SSL Terminating status
bitninjacli --module=WAF --status
bitninjacli --module=SslTerminating --status

# Check if SSL certificates are loaded
bitninjacli --module=SslTerminating --force-recollect

# Configure in dashboard
# Visit: https://admin.bitninja.io
```

---

## 🌐 Access Your Nextcloud

### After DNS Configuration
```
https://your-domain.com
```

**Default Login:**
- Username: `admin`
- Password: Check `/root/system-setup/.passwords` for the generated password

---

## 📊 Quick Diagnostics

### Check Services
```bash
systemctl status apache2
systemctl status mariadb
systemctl status redis-server
systemctl status bitninja
systemctl status fail2ban
```

### Check Nextcloud
```bash
# Status
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ status

# Check for issues
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ config:list system

# Check trusted domains
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ config:list system trusted_domains
```

### Check BitNinja WAF 2.0
```bash
# Status
bitninjacli --status

# WAF 2.0 status
bitninjacli --module=WAF --status

# SSL Terminating status
bitninjacli --module=SslTerminating --status

# View incidents (blocked attacks)
bitninjacli --incidents

# Dashboard
# https://admin.bitninja.io
```

### Check Firewall
```bash
# UFW status
sudo ufw status

# Check listening ports
sudo ss -tlnp | grep -E ':(22|80|443|60413)'
```

### Check SSL Certificates
```bash
# Check certbot timer status
systemctl status certbot.timer
systemctl list-timers certbot.timer

# List Let's Encrypt certificates
certbot certificates

# Test renewal (dry run - no actual renewal)
certbot renew --dry-run

# Check certificate expiration
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -noout -enddate
```

### View Logs
```bash
# Nextcloud
sudo tail -f $NEXTCLOUD_WEB_DIR/data/nextcloud.log

# Apache
sudo tail -f /var/log/apache2/nextcloud-error.log

# BitNinja WAF 2.0
sudo tail -f /var/log/bitninja/waf.log

# Certbot (renewal logs)
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# System check
sudo tail -f $LOGS_DIR/deployment.log
   # Or watch system verification
   sudo tail -f $LOGS_DIR/system-verification.log
```

---

## 🐛 Troubleshooting

### Can't Access Nextcloud

**🔍 Quick Diagnostic:**

Run the automated diagnostic script to identify issues:
```bash
sudo bash /root/system-setup/scripts/_18_external_access_diagnostic.sh
```

This will check:
- DNS configuration
- Firewall rules
- DNAT configuration
- Listening ports
- SSL certificates
- BitNinja status
- Connectivity tests

**Testing HTTPS Access:**

**From the server (localhost testing):**
```bash
# Test Apache directly (HTTP backend)
curl http://127.0.0.1:80/

# Test BitNinja with domain name (requires DNS and SNI)
curl -k https://your-domain.com/

# Note: BitNinja requires SNI (Server Name Indication)
# Using IP address will result in "400 Bad Request"
```

**From external machine (proper testing):**
```bash
# Test via IP address (BitNinja will use default certificate)
curl -k https://SERVER_IP/

# Test via domain name (recommended - uses proper certificate)
curl -k https://your-domain.com/
```

**Diagnostic Steps:**

1. Check Apache: `systemctl status apache2`
2. Check BitNinja: `systemctl status bitninja`
3. Check SSL certificate: `certbot certificates`
4. Check firewall: `sudo ufw status`
5. Test Apache config: `apache2ctl -t`
6. Check DNS: `dig your-domain.com`
7. Verify Apache is bound to localhost: `sudo ss -tlnp | grep :80`
8. Verify BitNinja SSL Terminating: `bitninjacli --module=SslTerminating --status`
9. Verify listening ports:
    ```bash
    # Apache should be on 127.0.0.1:80
    sudo ss -tlnp | grep :80 | grep apache
    
    # BitNinja should be on 0.0.0.0:443
    sudo ss -tlnp | grep :443 | grep bitninja
    
    # BitNinja internal ports should be on 127.0.0.1
    sudo ss -tlnp | grep bitninja | grep -E ':(60415|60418)'
    ```

### Can't Ping Out / No Outbound Connectivity

If you can't ping external hosts or access HTTP/HTTPS from the server:

1. **Check UFW default policies:**
   ```bash
   sudo ufw status verbose
   ```
   Should show: `Default: deny (incoming), allow (outgoing), allow (routed)`

2. **Check if UFW is blocking outbound:**
   ```bash
   sudo iptables -L OUTPUT -n -v
   ```

3. **Verify loopback is allowed:**
   ```bash
   sudo ufw status | grep lo
   ```

4. **Test connectivity:**
   ```bash
   ping -c 4 8.8.8.8          # Test ICMP
   curl -I https://google.com  # Test HTTPS
   dig google.com              # Test DNS
   ```

5. **Check for iptables-restore errors:**
   ```bash
   sudo ufw reload
   ```
   If you see "No chain/target/match by that name" errors, check the UFW configuration files.

6. **If still blocked, reset UFW:**
   ```bash
   sudo ufw --force reset
   sudo ufw default deny incoming
   sudo ufw default allow outgoing
   sudo ufw default allow routed
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow in on lo
   sudo ufw allow out on lo
   sudo ufw --force enable
   
   # Then re-add DNAT rule
   sudo /root/system-setup/scripts/_10_bitninja_installation.sh
   ```

### Database Connection Errors

1. Check MariaDB: `systemctl status mariadb`
2. Test connection: `mysql -u nextcloud -p`
3. Verify password in: `$NEXTCLOUD_WEB_DIR/config/config.php`
4. Check MariaDB is bound to localhost: `sudo ss -tlnp | grep :3306`

### SSL Certificate Issues

1. Check if certificate exists: `certbot certificates`
2. Check DNS is correct: `dig your-domain.com`
3. Check certbot timer: `systemctl status certbot.timer`
4. Test renewal: `certbot renew --dry-run`
5. Check certbot logs: `tail -f /var/log/letsencrypt/letsencrypt.log`
6. Manually rerun: `/root/system-setup/scripts/_7_ssl_certificate.sh`
7. Force BitNinja recollect: `bitninjacli --module=SslTerminating --force-recollect && bitninjacli --module=SslTerminating --restart`

### BitNinja WAF 2.0 Not Working

1. Check if installed: `which bitninjacli`
2. Check service: `systemctl status bitninja`
3. Verify license key: `bitninjacli --get-license-key`
4. Check WAF status: `bitninjacli --module=WAF --status`
5. Check SSL Terminating: `bitninjacli --module=SslTerminating --status`
6. Check WAFManager status: `bitninjacli --module=WAFManager --status` (look for `"isSsl": true`)
7. Check if ConfigParser detected certificates:
   ```bash
   cat /var/lib/bitninja/ConfigParser/getCerts-report.json
   cat /opt/bitninja-ssl-termination/etc/haproxy/cert-list.lst
   ```
8. If `"isSsl": false`, manually add certificate and restart BitNinja:
   ```bash
   # Replace your-domain.com with your actual domain
   bitninjacli --module=SslTerminating --add-cert \
     --domain=your-domain.com \
     --certFile=/etc/letsencrypt/live/your-domain.com/fullchain.pem \
     --keyFile=/etc/letsencrypt/live/your-domain.com/privkey.pem
   
   bitninjacli --module=SslTerminating --force-recollect
   systemctl restart bitninja
   sleep 10
   
   # Verify SSL is now enabled
   bitninjacli --module=WAFManager --status | grep isSsl
   ```
9. Rerun installation: `/root/system-setup/scripts/_9_bitninja_installation.sh`

### IPv6 Issues

1. Check if IPv6 is disabled: `cat /proc/sys/net/ipv6/conf/all/disable_ipv6`
2. Should show `1` if properly disabled
3. Restart if needed: `sudo reboot`

---

## 💡 Pro Tips

### Regular Maintenance

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Update Nextcloud
sudo -u www-data php $NEXTCLOUD_WEB_DIR/updater/updater.phar

# Check for issues
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ config:list

# Run system check
/root/system-setup/scripts/_13_system_verification.sh
```

### Backups

**Critical directories to backup:**
```bash
# Nextcloud config
$NEXTCLOUD_WEB_DIR/config/

# User data
$NEXTCLOUD_DATA_DIR/

# Database
mysqldump -u nextcloud -p nextcloud > nextcloud_backup.sql

# System configuration
sudo tar -czf system-config-backup.tar.gz /root/system-setup/
```

### Performance Monitoring

```bash
# Check disk space
df -h $NEXTCLOUD_DATA_DIR

# Check memory
free -h

# Check services
systemctl status apache2 mariadb redis-server bitninja

# Monitor BitNinja
bitninja-cli --incidents
```

### Useful Commands

#### System Management
```bash
# Check all services at once
systemctl status apache2 mariadb redis-server bitninja fail2ban

# View system resources
htop

# Check network connections
sudo ss -tlnp

# View system logs
sudo journalctl -f

# Check BitNinja logs
sudo tail -f /var/log/bitninja/waf.log

# Check certbot timer
systemctl list-timers certbot.timer
```

#### Nextcloud Management
```bash
# Run comprehensive system requirements check
/root/system-setup/scripts/_13_system_verification.sh

# Check Nextcloud status
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ status

# Run maintenance mode
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ maintenance:mode --on
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ maintenance:mode --off

# Update Nextcloud
sudo -u www-data php $NEXTCLOUD_WEB_DIR/updater/updater.phar
# (or use web interface)

# Check configuration
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ config:list system

# Scan for new files
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ files:scan --all
```

---

## 🔄 Configuration Details

### System Requirements
- **OS:** Ubuntu 24.04 LTS server
- **RAM:** Minimum 1GB, Recommended 2GB+
- **CPU:** Minimum 1 core, Recommended 2+ cores
- **Disk:** Minimum 5GB, Recommended 20GB+
- **Network:** Public IP with DNS configured

### Directory Structure
```
/root/system-setup/
├── scripts/           # All automation scripts (downloaded from GitHub)
├── logs/             # System and setup logs
├── downloads/        # Downloaded files
├── config.sh         # Central configuration file
└── .passwords        # Generated passwords (secure, 600 permissions)

$NEXTCLOUD_WEB_DIR/   # NextCloud web files
$NEXTCLOUD_DATA_DIR/  # NextCloud user data

GitHub Repository Structure:
├── scripts/          # All automation scripts
│   ├── _1_directory_structure.sh
│   ├── _2_system_initialization.sh
│   ├── _3_firewall_configuration.sh
│   ├── _4_security_hardening.sh
│   ├── _5_system_update.sh             # Full system update (apt-get update/upgrade/dist-upgrade)
│   ├── _6_php_configuration.sh
│   ├── _7_apache_configuration.sh
│   ├── _8_ssl_certificate.sh           # Automated Let's Encrypt certificate acquisition
│   ├── _9_redis_configuration.sh
│   ├── _10_bitninja_installation.sh
│   ├── _11_password_generation.sh
│   ├── _12_mariadb_configuration.sh
│   ├── _13_nextcloud_installation.sh
│   ├── _14_system_optimization.sh
│   ├── _15_system_verification.sh
│   ├── _16_service_security_verification.sh
│   └── _17_cleanup.sh
├── conf/             # All configuration files
│   ├── 50ubuntu-unattended-upgrades
│   ├── fail2ban-bitninja-captcha.conf
│   ├── fail2ban-bitninja-waf.conf
│   ├── fail2ban-jail.local
│   ├── fail2ban-nextcloud.conf
│   ├── nextcloud-apache-vhost.conf
│   └── nextcloud-mariadb.cnf
├── ubuntu-bitninja-nextcloud-cloud-config.yaml
├── README.md
└── LICENSE.md
```

### Firewall Rules

#### External Ports (UFW)
All UFW rules are configured with **explicit destination IP** (`SERVER_IP`) for security:

- **SSH:** Port 22 (TCP) → `SERVER_IP:22`
- **HTTP:** Port 80 (TCP) → `SERVER_IP:80` - Let's Encrypt HTTP-01 challenges (certbot standalone)
- **HTTPS:** Port 443 (TCP) → `SERVER_IP:443` - BitNinja WAF 2.0 (direct connection)
- **HTTPS Captcha:** Port 60413 (TCP) → `SERVER_IP:60413` - BitNinja HttpsCaptcha (if enabled)

**UFW Rule Format:**
```bash
# Simplified rules that work for both IPv4-only and IPv4+IPv6 configurations
ufw allow proto tcp from any to SERVER_IP port 22 comment 'SSH administration'
ufw allow proto tcp from any to SERVER_IP port 80 comment 'HTTP - Lets Encrypt challenges'
ufw allow proto tcp from any to SERVER_IP port 443 comment 'HTTPS - BitNinja WAF'
ufw allow proto tcp from any to SERVER_IP port 60413 comment 'HTTPS Captcha - BitNinja (if enabled)'
```

**Benefits:** 
- ✅ Explicit destination IP (`SERVER_IP`) - rules only apply to the public IP
- ✅ Single rule format - no conditional logic for IPv4-only vs IPv4+IPv6
- ✅ More secure - prevents unintended access on other interfaces
- ✅ BitNinja listens on the **public IP** (`SERVER_IP:443`)
- ✅ Apache and other services (MariaDB, Redis) listen on **localhost only** (`127.0.0.1`)

---

## 🔒 BitNinja Network Binding

BitNinja uses a **mixed binding strategy** for security:

**Public Ports (External Access):**
- **Port 443** (HTTPS): Listens on `0.0.0.0` (all interfaces), restricted by UFW to `SERVER_IP` only
- **Port 60413** (HTTPS Captcha): Listens on `0.0.0.0` (all interfaces), restricted by UFW to `SERVER_IP` only

**Internal Ports (Localhost Only):**
- **Port 60415** (WAF HTTP Proxy): Listens on `127.0.0.1` only (not exposed externally)
- **Port 60418** (XCaptcha HTTPS): Listens on `127.0.0.1` only (not exposed externally)

**Why This Approach:**
- BitNinja's configuration files regenerate automatically, but we make them **immutable** using `chattr +i`
- Public ports (443, 60413) use UFW firewall to restrict access to `SERVER_IP` only
- Internal ports (60415, 60418) are bound to localhost for defense-in-depth security
- This provides multiple layers of protection

**Security Model:**
```
Internet → UFW Firewall (allows only SERVER_IP:443) → BitNinja (0.0.0.0:443) → Apache (127.0.0.1:80)
                                                            ↓
                                                    Internal Ports (127.0.0.1:60415, 60418)
```

**Configuration:**
- **BitNinja Port 443**: Listens on `0.0.0.0:443` (SSL termination) - UFW restricts to `SERVER_IP`
- **BitNinja Port 60413**: Listens on `0.0.0.0:60413` (HTTPS Captcha) - UFW restricts to `SERVER_IP`
- **BitNinja Port 60415**: Listens on `127.0.0.1:60415` (WAF HTTP proxy) - localhost only
- **BitNinja Port 60418**: Listens on `127.0.0.1:60418` (XCaptcha HTTPS) - localhost only
- **Apache**: Listens on `127.0.0.1:80` (HTTP backend) - localhost only

**Benefits:**
- ✅ Works with BitNinja's automatic configuration regeneration
- ✅ UFW provides the security layer (industry standard)
- ✅ Simple and reliable - no fighting with BitNinja's config management
- ✅ Apache backend isolated on localhost
- ✅ All traffic passes through WAF before reaching Apache
- ✅ Defense in depth security model

**Verification:**
```bash
# Check BitNinja public ports (should listen on 0.0.0.0)
sudo ss -tlnp | grep bitninja | grep -E ':(443|60413)'
# Should show: 0.0.0.0:443 and 0.0.0.0:60413

# Check BitNinja internal ports (should listen on 127.0.0.1 only)
sudo ss -tlnp | grep bitninja | grep -E ':(60415|60418)'
# Should show: 127.0.0.1:60415 and 127.0.0.1:60418

# Verify immutable config files
sudo lsattr /opt/bitninja-ssl-termination/etc/haproxy/configs/*.cfg
# Should show 'i' flag (immutable) on ssl_termiantion.cfg, waf_proxy_http.cfg, xcaptcha_https_multiport.cfg
```

---

### Security Features
- **IPv6:** Disabled system-wide
- **Network Binding Strategy:**
  - **Public Ports (UFW-restricted):**
    - BitNinja Port 443: 0.0.0.0:443 (HTTPS - SSL termination)
    - BitNinja Port 60413: 0.0.0.0:60413 (HTTPS Captcha)
  - **Localhost-Only Services:**
    - Apache: 127.0.0.1:80 (HTTP backend)
    - BitNinja Port 60415: 127.0.0.1:60415 (WAF HTTP proxy)
    - BitNinja Port 60418: 127.0.0.1:60418 (XCaptcha HTTPS)
    - MariaDB: 127.0.0.1:3306
    - Redis: 127.0.0.1:6379
- **BitNinja WAF 2.0:** Web application firewall with SSL Terminating module
  - Public ports controlled by UFW firewall (restricted to SERVER_IP)
  - Internal ports bound to localhost only (immutable config files)
  - Firewall management disabled (UFW manages all rules)
- **SSL Certificates:** Automated Let's Encrypt via certbot (auto-renewal every 60 days)
- **fail2ban:** SSH, Apache, NextCloud, BitNinja protection
- **UFW:** IPv4-only, minimal port exposure (SSH, HTTP, HTTPS, HTTPS Captcha)

---

## 🆘 Support Resources

### Nextcloud
- [Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Community Forum](https://help.nextcloud.com)
- [GitHub Issues](https://github.com/nextcloud/server/issues)

### BitNinja
- [WAF 2.0 Documentation](https://doc.bitninja.io/docs/Modules/waf)
- [SSL Terminating Module](https://doc.bitninja.io/docs/Modules/ssl-terminating)
- [Installation Guide](https://doc.bitninja.io/docs/Installation/Install_BitNinja)
- [Dashboard](https://admin.bitninja.io)
- Email: support@bitninja.com

### Certbot / Let's Encrypt
- [Certbot Documentation](https://eff-certbot.readthedocs.io/)
- [User Guide](https://eff-certbot.readthedocs.io/en/stable/using.html)
- [Let's Encrypt Community](https://community.letsencrypt.org/)

### Ubuntu
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)
- [Community Support](https://help.ubuntu.com)

---

## 📝 License & Credits

### This Configuration
- Created following official Nextcloud and BitNinja documentation
- Free to use and modify for your own projects
- Includes comprehensive security hardening and optimization

### Software Licenses
- **Nextcloud:** AGPLv3
- **BitNinja:** Commercial (requires license)
- **Ubuntu:** Free and open source
- **Apache, PHP, MariaDB:** Open source

---

## 🎓 Learn More

### Recommended Reading

1. **Nextcloud Security Best Practices**
   - [Hardening Guide](https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html)
   
2. **Server Tuning**
   - [Performance Optimization](https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html)

3. **BitNinja WAF 2.0 Features**
   - [WAF 2.0 Documentation](https://doc.bitninja.io/docs/Modules/waf)
   - [SSL Terminating Module](https://doc.bitninja.io/docs/Modules/ssl-terminating)
   - [Protection Modules](https://doc.bitninja.io)

4. **Ubuntu Security**
   - [Ubuntu Security Guide](https://ubuntu.com/server/docs/security)

---

## 📞 Getting Help

If you encounter issues:

1. **Read the documentation:**
   - This README.md (comprehensive guide with all setup instructions)
   - Individual config files in `/root/system-setup/conf/` on your server

2. **Run diagnostics:**
   ```bash
   /root/system-setup/scripts/_13_system_verification.sh
   ```

3. **Check logs:**
   - Nextcloud: `$NEXTCLOUD_WEB_DIR/data/nextcloud.log`
   - Apache: `/var/log/apache2/nextcloud-error.log`
   - BitNinja: `/var/log/bitninja/waf.log`
   - Certbot: `/var/log/letsencrypt/letsencrypt.log`
   - System: `/var/log/syslog`

4. **Community support:**
   - Nextcloud: [https://help.nextcloud.com](https://help.nextcloud.com)
   - BitNinja: support@bitninja.com
   - Ubuntu: [https://help.ubuntu.com](https://help.ubuntu.com)

---

## ⭐ Contributing

Found an issue or improvement? Contributions welcome!

---

**Built with ❤️ following official documentation**

**Compatible with:** Ubuntu 24.04 LTS, Nextcloud Latest, PHP 8.3, MariaDB 10.x, BitNinja WAF 2.0

**Last Updated:** October 2025

**Key Features:**
- 🔒 **Production-Ready Security:** BitNinja WAF 2.0 with SSL Terminating
- 🔐 **Automated SSL:** Let's Encrypt certificates via certbot with auto-renewal
- ⚡ **High Performance:** Redis caching, MariaDB optimization, OPcache
- 🛡️ **Hardened System:** IPv6 disabled, localhost-only services
- 📦 **Complete Stack:** All required components and modules
- 🔧 **Easy Maintenance:** Variable-based configuration, organized scripts
- 📚 **Comprehensive Docs:** Detailed troubleshooting and maintenance guides