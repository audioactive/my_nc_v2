#####################################################################
# Carsten Rieger IT-Services
# https://www.c-rieger.de
# https://github.com/criegerde
# INSTALL-NEXTCLOUD-MARIADB-UBUNTU.SH
# Version 10 (AMD64)
# Nextcloud 16
# OpenSSL 1.1.1, TLSv1.3, NGINX 1.17 mainline, PHP 7.3, MariaDB 10.4
# August, 2nd 2019
#####################################################################
# Ubuntu Bionic Beaver 18.04.x AMD64 and ARM64, Nextcloud 16
#####################################################################
#!/bin/bash
###global function to update and cleanup the environment
function update_and_clean() {
apt update
apt upgrade -y
apt autoclean -y
apt autoremove -y
}
###global function to restart all cloud services
function restart_all_services() {
/usr/sbin/service nginx restart
/usr/sbin/service mysql restart
/usr/sbin/service redis-server restart
/usr/sbin/service php7.3-fpm restart
}
###global function to scan Nextcloud data and generate an overview for fail2ban & ufw
function nextcloud_scan_data() {
sudo -u www-data php /var/www/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/nextcloud/occ files:scan-app-data
#fail2ban-client status nextcloud
ufw status verbose
}
### START ###
mkdir -p /etc/letsencrypt/rsa-certs /etc/letsencrypt/ecc-certs
cd ~/.acme.sh
./acme.sh --issue -d bmbonly.com --keylength 4096 -w /var/www/letsencrypt --key-file /etc/letsencrypt/rsa-certs/privkey.pem --ca-file /etc/letsencrypt/rsa-certs/chain.pem --cert-file /etc/letsencrypt/rsa-certs/cert.pem --fullchain-file /etc/letsencrypt/rsa-certs/fullchain.pem
./acme.sh --issue -d bmbonly.com --keylength ec-384 -w /var/www/letsencrypt --key-file /etc/letsencrypt/ecc-certs/privkey.pem --ca-file /etc/letsencrypt/ecc-certs/chain.pem --cert-file /etc/letsencrypt/ecc-certs/cert.pem --fullchain-file /etc/letsencrypt/ecc-certs/fullchain.pem

###apply permissions
touch /root/permissions.sh
cat <<EOF >>/root/permissions.sh
#!/bin/bash
find /var/www/ -type f -print0 | xargs -0 chmod 0640
find /var/www/ -type d -print0 | xargs -0 chmod 0750
chown -R www-data:www-data /var/www/
chown -R www-data:www-data /nc_data/
chmod 0644 /var/www/nextcloud/.htaccess
chmod 0644 /var/www/nextcloud/.user.ini
chmod 600 /etc/letsencrypt/rsa-certs/fullchain.pem
chmod 600 /etc/letsencrypt/rsa-certs/privkey.pem
chmod 600 /etc/letsencrypt/rsa-certs/chain.pem
chmod 600 /etc/letsencrypt/rsa-certs/cert.pem
chmod 600 /etc/letsencrypt/ecc-certs/fullchain.pem
chmod 600 /etc/letsencrypt/ecc-certs/privkey.pem
chmod 600 /etc/letsencrypt/ecc-certs/chain.pem
chmod 600 /etc/letsencrypt/ecc-certs/cert.pem
chmod 600 /etc/ssl/certs/dhparam.pem
exit 0
EOF
chmod +x /root/permissions.sh && /root/permissions.sh

###modify the ssl.conf and restart nginx
sed -i '/ssl-cert-snakeoil/d' /etc/nginx/ssl.conf
sed -i s/\#\ssl/\ssl/g /etc/nginx/ssl.conf
/usr/sbin/service nginx restart

echo "Go to bmbonly.com to finish the installation of nextcloud!"
echo "Press ENTER when done."
read
clear

sudo -u www-data php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value=bmbonly.com
sudo -u www-data php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=https://bmbonly.com
sudo -u www-data cp /var/www/nextcloud/config/config.php /var/www/nextcloud/config/config.php.bak
sudo -u www-data sed -i 's/^[ ]*//' /var/www/nextcloud/config/config.php
sudo -u www-data sed -i '/);/d' /var/www/nextcloud/config/config.php
sudo -u www-data cat <<EOF >>/var/www/nextcloud/config/config.php
'activity_expire_days' => 14,
'auth.bruteforce.protection.enabled' => true,
'blacklisted_files' => 
array (
0 => '.htaccess',
1 => 'Thumbs.db',
2 => 'thumbs.db',
),
'cron_log' => true,
'enable_previews' => true,
'enabledPreviewProviders' => 
array (
0 => 'OC\\Preview\\PNG',
1 => 'OC\\Preview\\JPEG',
2 => 'OC\\Preview\\GIF',
3 => 'OC\\Preview\\BMP',
4 => 'OC\\Preview\\XBitmap',
5 => 'OC\\Preview\\Movie',
6 => 'OC\\Preview\\PDF',
7 => 'OC\\Preview\\MP3',
8 => 'OC\\Preview\\TXT',
9 => 'OC\\Preview\\MarkDown',
),
'filesystem_check_changes' => 0,
'filelocking.enabled' => 'true',
'htaccess.RewriteBase' => '/',
'integrity.check.disabled' => false,
'knowledgebaseenabled' => false,
'logfile' => '/nc_data/nextcloud.log',
'loglevel' => 2,
'logtimezone' => 'America/New York',
'log_rotate_size' => 104857600,
'maintenance' => false,
'memcache.local' => '\\OC\\Memcache\\APCu',
'memcache.locking' => '\\OC\\Memcache\\Redis',
'overwriteprotocol' => 'https',
'preview_max_x' => 1024,
'preview_max_y' => 768,
'preview_max_scale_factor' => 1,
'redis' => 
array (
'host' => '/var/run/redis/redis-server.sock',
'port' => 0,
'timeout' => 0.0,
),
'quota_include_external_storage' => false,
'share_folder' => '/Shares',
'skeletondirectory' => '',
'theme' => '',
'trashbin_retention_obligation' => 'auto, 7',
'updater.release.channel' => 'stable',
);
EOF
sudo -u www-data sed -i "s/output_buffering=.*/output_buffering='Off'/" /var/www/nextcloud/.user.ini
sudo -u www-data php /var/www/nextcloud/occ app:disable survey_client
sudo -u www-data php /var/www/nextcloud/occ app:disable firstrunwizard
sudo -u www-data php /var/www/nextcloud/occ app:enable admin_audit
sudo -u www-data php /var/www/nextcloud/occ app:enable files_pdfviewer
restart_all_services
update_and_clean
