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
fail2ban-client status nextcloud
ufw status verbose
}
### START ###
###install ufw
apt install ufw -y
###open firewall ports 80+443 for http(s)
ufw allow 80/tcp
ufw allow 443/tcp
###open firewall port 2222 for SSH
ufw allow 2222/tcp
###enable UFW (autostart)
ufw logging medium && ufw default deny incoming && ufw enable
###restart fail2ban, ufw and redis-server services
/usr/sbin/service ufw restart
/usr/sbin/service fail2ban restart
/usr/sbin/service redis-server restart
sudo -u www-data php /var/www/nextcloud/occ app:disable survey_client
sudo -u www-data php /var/www/nextcloud/occ app:disable firstrunwizard
sudo -u www-data php /var/www/nextcloud/occ app:enable admin_audit
sudo -u www-data php /var/www/nextcloud/occ app:enable files_pdfviewer
###clean up redis-server
redis-cli -s /var/run/redis/redis-server.sock <<EOF
FLUSHALL
quit
EOF
###Nextcloud occ db:... (maintenance/optimization)
/usr/sbin/service nginx stop
clear
echo "---------------------------------"
echo "Issue Nextcloud-DB optimizations!"
echo "---------------------------------"
echo "Press 'y' to issue optimizations."
echo "---------------------------------"
echo ""
sudo -u www-data php /var/www/nextcloud/occ db:add-missing-indices
sudo -u www-data php /var/www/nextcloud/occ db:convert-filecache-bigint
###rescan Nextcloud data
nextcloud_scan_data
restart_all_services
### issue the cron.php once
sudo -u www-data php /var/www/nextcloud/cron.php