# Ubuntu + Nextcloud + BitNinja WAF Pro Cloud-Config

## 📋 Overview

This cloud-config YAML provides a complete, production-ready installation of **Nextcloud** with **BitNinja WAF Pro** on **Ubuntu 24.04 LTS**, following official documentation from both projects.

### 🏗️ Architecture
```
Internet → BitNinja WAF Pro (Caddy + TLS 1.3) → Apache (localhost:80) → NextCloud
```

### Stack Components
- **Web Server:** Apache 2.4 with mod_php (localhost only)
- **PHP Version:** 8.3 with all required + recommended modules
- **Database:** MariaDB 10.x with utf8mb4, SSL enabled
- **Caching:** Redis + APCu (localhost only)
- **Security:** BitNinja WAF Pro, UFW firewall, fail2ban, IPv6 disabled
- **SSL:** BitNinja WAF Pro handles HTTPS termination with Let's Encrypt

---

## 🎯 Quick Start

### 1. Before Deployment

**Required Changes:**

1. **Update configuration variables** in the config section (lines 15-67):
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
✅ Apache configured for SSL termination  
✅ System requirements verified  
✅ Firewall configured (HTTPS, SSH, BitNinja Captcha ports)

**Components Configured:**
- Apache 2.4 with PHP 8.3 (mod_php)
- MariaDB with optimized settings
- Redis + APCu caching
- BitNinja security (automatically configured)
- UFW firewall enabled
- SSL termination configured for BitNinja

**Critical Files Created:**
- Setup Instructions: `/root/SETUP_INSTRUCTIONS.txt` (references README.md)
- Scripts Directory: `/root/system-setup/scripts/`
- Logs Directory: `/root/system-setup/logs/`
- Downloads Directory: `/root/system-setup/downloads/`
- Passwords File: `/root/system-setup/.passwords` (secure, 600 permissions)

**Main Scripts Available:**
- Auto-Complete Setup: `/root/system-setup/scripts/auto-complete-setup.sh`
- Comprehensive System Check: `/root/system-setup/scripts/comprehensive-system-check.sh`
- BitNinja Features: `/root/system-setup/scripts/configure-bitninja-features.sh`
- Nextcloud Install: `/root/system-setup/scripts/install-nextcloud.sh`
- BitNinja Install: `/root/system-setup/scripts/install-bitninja.sh`

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
/root/system-setup/scripts/comprehensive-system-check.sh

# 3. Optional: Run auto-complete setup verification
/root/system-setup/scripts/auto-complete-setup.sh

# 4. Check Nextcloud status
sudo -u www-data php $NEXTCLOUD_WEB_DIR/occ status

# 5. Review setup log
cat /root/system-setup/logs/comprehensive-system-check.log
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

**2. Configure BitNinja (if license key was not provided)**
```bash
# Use the helper script
/root/system-setup/scripts/install-bitninja.sh

# Or manual installation
curl https://get.bitninja.io/install.sh | sudo /bin/bash -s - --license_key=YOUR_LICENSE_KEY

# Verify BitNinja is running
systemctl status bitninja
bitninja-cli --version

# Login to BitNinja dashboard: https://admin.bitninja.io
# - Configure SSL certificates and Let's Encrypt integration
# - Review and customize protection rules as needed
# - Monitor security events and adjust settings
```

**3. Configure DNS**
- Point your domain to the server IP
- Wait for DNS propagation (can take up to 24-48 hours)
- Test with: `dig your-domain.com`

**4. Access Nextcloud**
After SSL setup:
- Navigate to: `https://your-domain.com`
- Username: `admin`
- Password: The one you set in step 1c

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
- **Comprehensive System Check:** `/root/system-setup/logs/comprehensive-system-check.log`
- Review this log for detailed system requirements check results

#### 🔒 Security Recommendations

**After First Login:**
- Change all passwords for enhanced security
- Review fail2ban status: `fail2ban-client status`
- Monitor BitNinja WAF Pro dashboard for security events

**Next Steps Summary:**
1. Optional: Run `/root/system-setup/scripts/auto-complete-setup.sh` to verify everything
2. Configure DNS: `your-domain.com` → server IP
3. Set up SSL certificates in BitNinja dashboard
4. Change default passwords (see security steps above)

**Documentation Resources:**
- [Nextcloud Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [BitNinja WAF Pro Documentation](https://doc.bitninja.io/docs/Modules/waf-pro)

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

### ✅ BitNinja WAF Pro (WAF3)
- **Modern Architecture:** Caddy-based with TLS 1.3 support
- **Built-in SSL Termination:** No separate SSL module needed
- **Enhanced Security:** Advanced threat detection and protection
- **Automatic Configuration:** All security features enabled automatically

### ✅ Nextcloud (Official Docs Compliant)
- **Complete PHP Stack:** All required and recommended PHP 8.3 modules
- **Optimized Database:** MariaDB with utf8mb4, SSL, and performance tuning
- **Caching Layer:** Redis + APCu for optimal performance
- **Security Hardened:** Proper file permissions, fail2ban, firewall rules
- **Emoji Support:** MySQL 4-byte support enabled

### ✅ System Security
- **IPv6 Disabled:** System-wide IPv6 disablement for security
- **Service Binding:** All services bound to localhost only
- **Firewall Configuration:** UFW with SSH, HTTPS, and BitNinja Captcha ports
- **Automatic Updates:** Unattended security updates enabled
- **System Hardening:** Disabled unnecessary services, secured shared memory

### ✅ Variable-Based Configuration
- **Centralized Settings:** All configuration in `/root/system-setup/config.sh`
- **No Hardcoded Values:** All paths and settings use variables
- **Easy Customization:** Modify settings in one place

---

## 📚 Scripts and Configuration Files

### 🔧 Helper Scripts

The cloud-config automatically downloads these scripts from GitHub during deployment:

| Script | Purpose | GitHub URL |
|--------|---------|------------|
| `comprehensive-system-check.sh` | Validate system requirements | [`scripts/comprehensive-system-check.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/comprehensive-system-check.sh) |
| `auto-complete-setup.sh` | Post-deployment verification | [`scripts/auto-complete-setup.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/auto-complete-setup.sh) |
| `install-nextcloud.sh` | Nextcloud CLI installer | [`scripts/install-nextcloud.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/install-nextcloud.sh) |
| `install-bitninja.sh` | BitNinja installer helper | [`scripts/install-bitninja.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/install-bitninja.sh) |
| `configure-bitninja-features.sh` | Enable all BitNinja features | [`scripts/configure-bitninja-features.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/configure-bitninja-features.sh) |
| `deploy-configs.sh` | Configuration deployment utility | [`scripts/deploy-configs.sh`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/scripts/deploy-configs.sh) |

### ⚙️ Configuration Files

All configuration files are downloaded from GitHub during deployment:

| Config File | Purpose | GitHub URL |
|-------------|---------|------------|
| `60-nextcloud.cnf` | MariaDB optimization settings | [`conf/60-nextcloud.cnf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/60-nextcloud.cnf) |
| `nextcloud.conf` | Apache virtual host configuration | [`conf/nextcloud.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/nextcloud.conf) |
| `jail.local` | fail2ban jail configuration | [`conf/jail.local`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/jail.local) |
| `nextcloud.conf` (fail2ban) | NextCloud fail2ban filter | [`conf/nextcloud.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/nextcloud.conf) |
| `bitninja-waf.conf` | BitNinja WAF fail2ban filter | [`conf/bitninja-waf.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/bitninja-waf.conf) |
| `bitninja-captcha.conf` | BitNinja Captcha fail2ban filter | [`conf/bitninja-captcha.conf`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/bitninja-captcha.conf) |
| `50unattended-upgrades` | Automatic security updates | [`conf/50unattended-upgrades`](https://raw.githubusercontent.com/mattx86/ubuntu-bitninja-nextcloud-cloud-config/main/conf/50unattended-upgrades) |

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

### Verify BitNinja WAF Pro

```bash
# Check if installed and running
systemctl status bitninja
bitninja-cli --version

# Check WAF Pro status
bitninja-cli --module=WAF3 --status

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

### Check BitNinja WAF Pro
```bash
# Status
bitninja-cli --status

# WAF Pro status
bitninja-cli --module=WAF3 --status

# View incidents (blocked attacks)
bitninja-cli --incidents

# Dashboard
# https://admin.bitninja.io
```

### Check Firewall
```bash
# UFW status
sudo ufw status

# Check listening ports
sudo netstat -tlnp | grep -E ':(22|80|443|60412|60413)'
```

### View Logs
```bash
# Nextcloud
sudo tail -f $NEXTCLOUD_WEB_DIR/data/nextcloud.log

# Apache
sudo tail -f /var/log/apache2/nextcloud-error.log

# BitNinja WAF Pro
sudo tail -f /var/log/bitninja-waf3/current.log
sudo tail -f /var/log/bitninja-waf3/audit.log

# System check
sudo tail -f $LOGS_DIR/comprehensive-system-check.log
```

---

## 🐛 Troubleshooting

### Can't Access Nextcloud

1. Check Apache: `systemctl status apache2`
2. Check firewall: `sudo ufw status`
3. Test config: `apache2ctl -t`
4. Check DNS: `dig your-domain.com`
5. Verify Apache is bound to localhost: `sudo netstat -tlnp | grep :80`

### Database Connection Errors

1. Check MariaDB: `systemctl status mariadb`
2. Test connection: `mysql -u nextcloud -p`
3. Verify password in: `$NEXTCLOUD_WEB_DIR/config/config.php`
4. Check MariaDB is bound to localhost: `sudo netstat -tlnp | grep :3306`

### BitNinja WAF Pro Not Working

1. Check if installed: `which bitninja-cli`
2. Install if needed: `/root/system-setup/scripts/install-bitninja.sh`
3. Check service: `systemctl status bitninja`
4. Verify license key: `bitninja-config --get license_key`
5. Check WAF Pro status: `bitninja-cli --module=WAF3 --status`

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
/root/system-setup/scripts/comprehensive-system-check.sh
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
sudo netstat -tlnp

# View system logs
sudo journalctl -f

# Check BitNinja logs
sudo tail -f /var/log/bitninja-waf3/current.log
```

#### Nextcloud Management
```bash
# Run comprehensive system requirements check
/root/system-setup/scripts/comprehensive-system-check.sh

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
│   ├── install-nextcloud.sh
│   ├── comprehensive-system-check.sh
│   ├── configure-bitninja-features.sh
│   ├── install-bitninja.sh
│   ├── auto-complete-setup.sh
│   └── deploy-configs.sh
├── conf/             # All configuration files
│   ├── 60-nextcloud.cnf
│   ├── nextcloud.conf (Apache)
│   ├── jail.local
│   ├── nextcloud.conf (fail2ban filter)
│   ├── bitninja-waf.conf
│   ├── bitninja-captcha.conf
│   └── 50unattended-upgrades
└── ubuntu-bitninja-nextcloud-cloud-config.yaml
```

### Firewall Rules
- **SSH:** Port 22 (TCP)
- **HTTPS:** Port 443 (TCP) - BitNinja WAF Pro
- **BitNinja Captcha:** Ports 60412, 60413 (TCP)

### Security Features
- **IPv6:** Disabled system-wide
- **Services:** Bound to localhost only
- **BitNinja WAF Pro:** TLS 1.3, built-in SSL termination
- **fail2ban:** SSH, Apache, NextCloud, BitNinja protection
- **UFW:** Minimal port exposure
- **MariaDB:** SSL enabled, root restricted
- **Redis:** Localhost only, dangerous commands disabled

---

## 🆘 Support Resources

### Nextcloud
- [Admin Manual](https://docs.nextcloud.com/server/latest/admin_manual/)
- [Community Forum](https://help.nextcloud.com)
- [GitHub Issues](https://github.com/nextcloud/server/issues)

### BitNinja
- [WAF Pro Documentation](https://doc.bitninja.io/docs/Modules/waf-pro)
- [Installation Guide](https://doc.bitninja.io/docs/Installation/Install_BitNinja)
- [Dashboard](https://admin.bitninja.io)
- Email: support@bitninja.com

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

## 🔄 Version History

### Current Version: v4.0
- ✅ **GitHub Integration:** All scripts and configs downloaded from GitHub during deployment
- ✅ **Modular Architecture:** Scripts and configurations separated for better maintainability
- ✅ **Comprehensive Documentation:** SETUP_INSTRUCTIONS.txt content merged into README.md
- ✅ **Configuration Management:** All config files documented with GitHub URLs
- ✅ **52.3% Size Reduction:** YAML file optimized from 65,610 to 31,310 bytes
- ✅ **BitNinja WAF Pro (WAF3):** Upgraded from WAF2 to Caddy-based WAF Pro
- ✅ **Variable-Based Configuration:** All hardcoded values replaced with variables
- ✅ **Modern MariaDB:** Updated authentication methods
- ✅ **Complete PHP Stack:** All required and recommended modules included
- ✅ **System Hardening:** IPv6 disabled, services bound to localhost
- ✅ **Enhanced Security:** BitNinja Captcha ports, comprehensive fail2ban
- ✅ **Organized Structure:** Scripts and logs in dedicated directories

### Previous Versions
- **v2.0:** BitNinja WAF2 with SSL termination
- **v1.0:** Basic Nextcloud installation

---

## 🎓 Learn More

### Recommended Reading

1. **Nextcloud Security Best Practices**
   - [Hardening Guide](https://docs.nextcloud.com/server/latest/admin_manual/installation/harden_server.html)
   
2. **Server Tuning**
   - [Performance Optimization](https://docs.nextcloud.com/server/latest/admin_manual/installation/server_tuning.html)

3. **BitNinja WAF Pro Features**
   - [WAF Pro Documentation](https://doc.bitninja.io/docs/Modules/waf-pro)
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
   /root/system-setup/scripts/comprehensive-system-check.sh
   ```

3. **Check logs:**
   - Nextcloud: `$NEXTCLOUD_WEB_DIR/data/nextcloud.log`
   - Apache: `/var/log/apache2/nextcloud-error.log`
   - BitNinja: `/var/log/bitninja-waf3/current.log`
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

**Compatible with:** Ubuntu 24.04 LTS, Nextcloud Latest, PHP 8.3, MariaDB 10.x, BitNinja WAF Pro

**Last Updated:** January 2025

**Key Features:**
- 🔒 **Production-Ready Security:** BitNinja WAF Pro with TLS 1.3
- ⚡ **High Performance:** Redis caching, MariaDB optimization, OPcache
- 🛡️ **Hardened System:** IPv6 disabled, localhost-only services
- 📦 **Complete Stack:** All required components and modules
- 🔧 **Easy Maintenance:** Variable-based configuration, organized scripts
- 📚 **Comprehensive Docs:** Detailed troubleshooting and maintenance guides