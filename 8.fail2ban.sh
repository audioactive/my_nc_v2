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
###install fail2ban
apt install fail2ban -y
###create a fail2ban Nextcloud filter
touch /etc/fail2ban/filter.d/nextcloud.conf
cat <<EOF >/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
failregex=^{"reqId":".*","remoteAddr":".*","app":"core","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)","level":2,"time":".*"}$
          ^{"reqId":".*","level":2,"time":".*","remoteAddr":".*","user,:".*","app":"no app in context".*","method":".*","message":"Login failed: '.*' \(Remote IP: '<HOST>'\)".*}$
          ^{"reqId":".*","level":2,"time":".*","remoteAddr":".*","user":".*","app":".*","method":".*","url":".*","message":"Login failed: .* \(Remote IP: <HOST>\).*}$
EOF
###create a fail2ban Nextcloud jail
touch /etc/fail2ban/jail.d/nextcloud.local
cat <<EOF >/etc/fail2ban/jail.d/nextcloud.local
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 5
bantime = 3600
findtime = 3600
logpath = /nc_data/nextcloud.log
[nginx-http-auth]
enabled = true
EOF
update_and_clean
/usr/sbin/service fail2ban restart

echo "Done with script 8.fail2ban.sh"