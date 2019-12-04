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
###install Redis-Server
apt install redis-server php-redis -y
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
sed -i "s/port 6379/port 0/" /etc/redis/redis.conf
sed -i s/\#\ unixsocket/\unixsocket/g /etc/redis/redis.conf
sed -i "s/unixsocketperm 700/unixsocketperm 770/" /etc/redis/redis.conf
sed -i "s/# maxclients 10000/maxclients 512/" /etc/redis/redis.conf
usermod -a -G redis www-data
cp /etc/sysctl.conf /etc/sysctl.conf.bak && sed -i '$avm.overcommit_memory = 1' /etc/sysctl.conf

echo "System will be rebooted."
echo "Press ENTER to reboot now."
read

shutdown -r now