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
###prepare NGINX for Nextcloud and SSL
[ -f /etc/nginx/conf.d/default.conf ] && mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak
touch /etc/nginx/conf.d/default.conf
cat <<EOF >/etc/nginx/conf.d/nextcloud.conf
server {
server_name bmbonly.com;
listen 80 default_server;
listen [::]:80 default_server;
location ^~ /.well-known/acme-challenge {
proxy_pass http://127.0.0.1:81;
proxy_set_header Host \$host;
}
location / {
return 301 https://\$host\$request_uri;
}
}
server {
server_name bmbonly.com;
listen 443 ssl http2 default_server;
listen [::]:443 ssl http2 default_server;
root /var/www/nextcloud/;
location = /robots.txt {
allow all;
log_not_found off;
access_log off;
}
location = /.well-known/carddav {
return 301 \$scheme://\$host/remote.php/dav;
}
location = /.well-known/caldav {
return 301 \$scheme://\$host/remote.php/dav;
}
#SOCIAL app enabled? Please uncomment the following row
#rewrite ^/.well-known/webfinger /public.php?service=webfinger last;
#WEBFINGER app enabled? Please uncomment the following two rows.
#rewrite ^/.well-known/host-meta /public.php?service=host-meta last;
#rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;
client_max_body_size 10240M;
location / {
rewrite ^ /index.php;
}
location ~ ^/(?:build|tests|config|lib|3rdparty|templates|data)/ {
deny all;
}
location ~ ^/(?:\.|autotest|occ|issue|indie|db_|console) {
deny all;
}
location ^~ /apps/rainloop/app/data {
deny all;
}
location ~ \.(?:flv|mp4|mov|m4a)\$ {
mp4;
mp4_buffer_size 100M;
mp4_max_buffer_size 1024M;
fastcgi_split_path_info ^(.+?.php)(\/.*|)\$;
set \$path_info \$fastcgi_path_info;
try_files \$fastcgi_script_name =404;
include fastcgi_params;
include php_optimization.conf;
}
location ~ ^\/(?:index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+).php(?:\$|\/) {
fastcgi_split_path_info ^(.+?.php)(\/.*|)\$;
set \$path_info \$fastcgi_path_info;
try_files \$fastcgi_script_name =404;
include fastcgi_params;
include php_optimization.conf;
}
location ~ ^\/(?:updater|oc[ms]-provider)(?:\$|\/) {
try_files \$uri/ =404;
index index.php;
}
location ~ .(?:css|js|woff2?|svg|gif|map|png|html|ttf|ico|jpg|jpeg)\$ {
try_files \$uri /index.php\$request_uri;
access_log off;
expires 360d;
}
}
EOF
###create a Let's Encrypt vhost file
touch /etc/nginx/conf.d/letsencrypt.conf
cat <<EOF >>/etc/nginx/conf.d/letsencrypt.conf
server {
server_name 127.0.0.1;
listen 127.0.0.1:81 default_server;
charset utf-8;
location ^~ /.well-known/acme-challenge {
default_type text/plain;
root /var/www/letsencrypt;
}
}
EOF
###create a ssl configuration file
touch /etc/nginx/ssl.conf
cat <<EOF >>/etc/nginx/ssl.conf
ssl_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
ssl_certificate_key /etc/ssl/private/ssl-cert-snakeoil.key;
ssl_trusted_certificate /etc/ssl/certs/ssl-cert-snakeoil.pem;
#ssl_certificate /etc/letsencrypt/rsa-certs/fullchain.pem;
#ssl_certificate_key /etc/letsencrypt/rsa-certs/privkey.pem;
#ssl_certificate /etc/letsencrypt/ecc-certs/fullchain.pem;                                                                                                                               
#ssl_certificate_key /etc/letsencrypt/ecc-certs/privkey.pem;                                                                                                                             
#ssl_trusted_certificate /etc/letsencrypt/ecc-certs/chain.pem;
ssl_dhparam /etc/ssl/certs/dhparam.pem;
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;
ssl_protocols TLSv1.3 TLSv1.2;
ssl_ciphers 'TLS-CHACHA20-POLY1305-SHA256:TLS-AES-256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384';
ssl_ecdh_curve secp521r1:secp384r1;
ssl_prefer_server_ciphers on;
ssl_stapling on;
ssl_stapling_verify on;
EOF
###create a proxy configuration file
touch /etc/nginx/proxy.conf
cat <<EOF >>/etc/nginx/proxy.conf
proxy_set_header Host \$host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-Host \$host;
proxy_set_header X-Forwarded-Protocol \$scheme;
proxy_set_header X-Forwarded-For \$remote_addr;
proxy_set_header X-Forwarded-Port \$server_port;
proxy_set_header X-Forwarded-Server \$host;
proxy_connect_timeout 3600;
proxy_send_timeout 3600;
proxy_read_timeout 3600;
proxy_redirect off;
EOF
###create a header configuration file
touch /etc/nginx/header.conf
cat <<EOF >>/etc/nginx/header.conf
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload;";
add_header X-Robots-Tag none;
add_header X-Download-Options noopen;
add_header X-Permitted-Cross-Domain-Policies none;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "no-referrer" always;
#add_header Feature-Policy "accelerometer 'none'; autoplay 'self'; geolocation 'none'; midi 'none'; sync-xhr 'self' ; microphone 'self'; camera 'self'; magnetometer 'none'; gyroscope 'none'; speaker 'self'; fullscreen 'self'; payment 'none'; usb 'none'";
EOF
###create a nginx optimization file
touch /etc/nginx/optimization.conf
cat <<EOF >>/etc/nginx/optimization.conf
fastcgi_hide_header X-Powered-By;
fastcgi_read_timeout 3600;
fastcgi_send_timeout 3600;
fastcgi_connect_timeout 3600;
fastcgi_buffers 64 64K;
fastcgi_buffer_size 256k;
fastcgi_busy_buffers_size 3840K;
fastcgi_cache_key \$http_cookie\$request_method\$host\$request_uri;
fastcgi_cache_use_stale error timeout invalid_header http_500;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
gzip on;
gzip_vary on;
gzip_comp_level 4;
gzip_min_length 256;
gzip_proxied expired no-cache no-store private no_last_modified no_etag auth;
gzip_types application/atom+xml application/javascript application/json application/ld+json application/manifest+json application/rss+xml application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json application/xhtml+xml application/xml font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;
gzip_disable "MSIE [1-6]\.";
EOF
###create a nginx php optimization file
touch /etc/nginx/php_optimization.conf
cat <<EOF >>/etc/nginx/php_optimization.conf
fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
fastcgi_param PATH_INFO \$fastcgi_path_info;
fastcgi_param HTTPS on;
fastcgi_param modHeadersAvailable true;
fastcgi_param front_controller_active true;
fastcgi_pass php-handler;
fastcgi_intercept_errors on;
fastcgi_request_buffering off;
fastcgi_cache_valid 404 1m;
fastcgi_cache_valid any 1h;
fastcgi_cache_methods GET HEAD;
EOF
###enhance security
openssl dhparam -out /etc/ssl/certs/dhparam.pem 4096
###enable all nginx configuration files
sed -i s/\#\include/\include/g /etc/nginx/nginx.conf
###restart NGINX
/usr/sbin/service nginx restart

echo "Done with script 5.nxtcloud_prep.sh"