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
###Download Nextclouds latest release and extract it
cd /usr/local/src
wget https://download.nextcloud.com/server/releases/latest.tar.bz2
tar -xjf latest.tar.bz2 -C /var/www
###apply permissions
chown -R www-data:www-data /var/www/
###remove the Nextcloud sources
rm -f latest.tar.bz2
###update and restart all sources and services
update_and_clean
restart_all_services
clear

###clone acme.sh from github
cd /usr/local/src
git clone https://github.com/Neilpang/acme.sh.git
cd acme.sh
chmod +x acme.sh
./acme.sh --install

echo "Restart terminal!"
echo "Press ENTER to continue."
read