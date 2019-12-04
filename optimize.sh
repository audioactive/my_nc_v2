#!/bin/bash
redis-cli -s /var/run/redis/redis-server.sock <<EOF
FLUSHALL
quit
EOF
sudo -u www-data php /var/www/nextcloud/occ files:scan --all
sudo -u www-data php /var/www/nextcloud/occ files:scan-app-data
exit 0