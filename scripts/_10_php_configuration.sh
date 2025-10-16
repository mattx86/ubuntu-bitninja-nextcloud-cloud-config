#!/bin/bash
# PHP Configuration Script
# Configures PHP with performance and security optimizations

source /root/system-setup/config.sh
log_and_console "=== PHP CONFIGURATION ==="
log_and_console "Configuring PHP for NextCloud..."

# PHP performance and security configuration
sed -i "s/memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/; s/upload_max_filesize = .*/upload_max_filesize = $PHP_UPLOAD_MAX/; s/post_max_size = .*/post_max_size = $PHP_POST_MAX/; s/max_execution_time = .*/max_execution_time = $PHP_MAX_EXECUTION/; s/max_input_time = .*/max_input_time = $PHP_MAX_INPUT/; s/;date.timezone =.*/date.timezone = $TIMEZONE/" /etc/php/8.3/apache2/php.ini

# OPcache optimization for NextCloud
sed -i "s/;opcache.enable=.*/opcache.enable=$OPCACHE_ENABLE/; s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=$OPCACHE_STRING_BUFFER/; s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=$OPCACHE_MAX_FILES/; s/;opcache.memory_consumption=.*/opcache.memory_consumption=$OPCACHE_MEMORY/; s/;opcache.save_comments=.*/opcache.save_comments=1/; s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/8.3/apache2/php.ini

# PHP security hardening
sed -i 's/expose_php = .*/expose_php = Off/; s/;session.cookie_secure =.*/session.cookie_secure = 1/; s/;session.cookie_httponly =.*/session.cookie_httponly = 1/; s/;session.use_strict_mode =.*/session.use_strict_mode = 1/' /etc/php/8.3/apache2/php.ini
log_and_console "✓ PHP configured with performance and security optimizations"
