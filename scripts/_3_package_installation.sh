#!/bin/bash
# Package Installation Script
# Installs all required packages for Nextcloud, Apache, PHP, MariaDB, Redis, and BitNinja

source /root/system-setup/config.sh
log_and_console "=== PACKAGE INSTALLATION ==="
log_and_console "Installing required packages..."

# Set non-interactive mode for apt
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1

# Install packages with progress logging
log_and_console "Installing system utilities..."
apt-get install -y \
  curl \
  wget \
  gnupg \
  ca-certificates \
  software-properties-common \
  apt-transport-https \
  unzip \
  zip \
  bzip2 \
  locate \
  bc \
  net-tools \
  apg \
  htop \
  nano \
  vim \
  tree \
  | tee -a "$LOG_FILE"

log_and_console "Installing security tools..."
apt-get install -y \
  ufw \
  fail2ban \
  certbot \
  dnsutils \
  | tee -a "$LOG_FILE"

log_and_console "Installing web server and PHP..."
apt-get install -y \
  apache2 \
  libapache2-mod-php8.3 \
  php8.3 \
  php8.3-cli \
  php8.3-common \
  php8.3-mysql \
  php8.3-zip \
  php8.3-gd \
  php8.3-mbstring \
  php8.3-curl \
  php8.3-xml \
  php8.3-bcmath \
  php8.3-intl \
  imagemagick \
  php8.3-imagick \
  php8.3-gmp \
  php8.3-apcu \
  php8.3-redis \
  php8.3-ldap \
  php8.3-bz2 \
  php8.3-fileinfo \
  php8.3-dom \
  php8.3-json \
  php8.3-openssl \
  php8.3-posix \
  php8.3-session \
  php8.3-simplexml \
  php8.3-xmlreader \
  php8.3-xmlwriter \
  php8.3-zlib \
  php8.3-ctype \
  php8.3-iconv \
  php8.3-pcntl \
  php8.3-tokenizer \
  | tee -a "$LOG_FILE"

log_and_console "Installing database and caching..."
apt-get install -y \
  mariadb-server \
  mariadb-client \
  redis-server \
  | tee -a "$LOG_FILE"

log_and_console "✓ All packages installed successfully"
log_and_console ""
log_and_console "Installed components:"
log_and_console "  - Apache $(apache2 -v | head -n1 | awk '{print $3}')"
log_and_console "  - PHP $(php -v | head -n1 | awk '{print $2}')"
log_and_console "  - MariaDB $(mysql --version | awk '{print $5}' | sed 's/,//')"
log_and_console "  - Redis $(redis-server --version | awk '{print $3}' | cut -d'=' -f2)"
log_and_console "  - Certbot $(certbot --version | awk '{print $2}')"
log_and_console "  - UFW $(ufw version | head -n1 | awk '{print $2}')"
log_and_console ""

