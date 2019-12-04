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
apt install curl gnupg2 git lsb-release ssl-cert ca-certificates apt-transport-https tree locate software-properties-common dirmngr screen htop net-tools zip unzip curl ffmpeg ghostscript libfile-fcntllock-perl -y
###prepare the server environment
cd /etc/apt/sources.list.d
echo "deb [arch=amd64] http://ppa.launchpad.net/ondrej/php/ubuntu $(lsb_release -cs) main" | tee php.list
#echo "deb [arch=amd64] http://ppa.launchpad.net/ondrej/nginx-mainline/ubuntu $(lsb_release -cs) main" | tee nginx.list
echo "deb [arch=amd64] http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" | tee nginx.list
echo "deb [arch=amd64] http://ftp.hosteurope.de/mirror/mariadb.org/repo/10.4/ubuntu $(lsb_release -cs) main" | tee mariadb.list
###
curl -fsSL https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
apt-key adv --recv-keys --keyserver hkps://keyserver.ubuntu.com:443 4F4EA0AAE5267A6C
apt-key adv --recv-keys --keyserver hkps://keyserver.ubuntu.com:443 0xF1656F24C74CD1D8   
update_and_clean
apt update && apt upgrade -y && apt install ssl-cert -y && make-ssl-cert generate-default-snakeoil
apt remove nginx nginx-extras nginx-common nginx-full -y --allow-change-held-packages
###instal NGINX using TLSv1.3, OpenSSL 1.1.1
update_and_clean
apt install nginx -y
###enable NGINX autostart
systemctl enable nginx.service
### prepare the NGINX
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak && touch /etc/nginx/nginx.conf
cat <<EOF >/etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /var/run/nginx.pid;
events {
worker_connections 1024;
multi_accept on;
use epoll;
}
http {
server_names_hash_bucket_size 64;
upstream php-handler {
server unix:/run/php/php7.3-fpm.sock;
}
set_real_ip_from 127.0.0.1;
set_real_ip_from 192.168.1.0/24;
real_ip_header X-Forwarded-For;
real_ip_recursive on;
include /etc/nginx/mime.types;
#include /etc/nginx/proxy.conf;
#include /etc/nginx/ssl.conf;
#include /etc/nginx/header.conf;
#include /etc/nginx/optimization.conf;
default_type application/octet-stream;
access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log warn;
sendfile on;
send_timeout 3600;
tcp_nopush on;
tcp_nodelay on;
open_file_cache max=500 inactive=10m;
open_file_cache_errors on;
keepalive_timeout 65;
reset_timedout_connection on;
server_tokens off;
resolver 127.0.0.1 valid=30s; 
resolver_timeout 5s;
include /etc/nginx/conf.d/*.conf;
}
EOF
###restart NGINX
/usr/sbin/service nginx restart
###create folders
mkdir -p /var/www/letsencrypt
###apply permissions
chown -R www-data:www-data /nc_data /var/www

echo "Done with script 1.ngixn.sh"