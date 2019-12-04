#!/bin/bash

set -e

# mount bkup disk
if grep -qs "/bkup" /proc/mounts;
then
	echo "Backup drive is mounted!"
else
	mount /bkup
	echo "Successfully mounted backup drive!"
fi

# enable Maintenance Mode to prevent users from working with Nextcloud
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on

# folder where the final tar backup files will be saved to
final_target_path="/bkup"
mkdir -p "${final_target_path}"

# folder where the files will be copied to initially before compressing them
int_target_path="/bkup_repo"
mkdir -p "${int_target_path}"

# print start date/time 
echo "START: $(date)"

# list of folders to be backed up, feel free to add/remove directories
FOLDERS_TO_BACKUP=(
"/root/"
"/etc/fail2ban/"
"/etc/letsencrypt/"
"/etc/mysql/"
"/etc/nginx/"
"/etc/php/"
"/etc/ssh/"
"/etc/pam.d/"
"/etc/ssl/"
"/var/www/"
"/nc_data/heman/"
"/nc_data/msp/"
"/nc_data/bia/"
)

for item in "${FOLDERS_TO_BACKUP[@]}"
do
	if [ -d "$item" ];
	then
		echo "Copying $item"
		include_args="${include_args} ${item}"
	else
		echo "Skipping $item (does not exist!)"
	fi
done

rsync -AaRx --delete ${include_args} ${int_target_path}

# copy the fstab
[ -f /etc/fstab ] && cp /etc/fstab ${int_target_path}

# create a database bkup
mysqldump --single-transaction -hlocalhost -uheman -p"H3m4n@db" nxtcld > $int_target_path/ncdb_`date +"%w"`.sql

# print the database backup size
mysql -hlocalhost -uheman -p"H3m4n@db" -e "SELECT table_schema 'DB',round(sum(data_length+index_length)/1024/1024,1) 'Size (MB)' from information_schema.tables WHERE table_schema = 'nxtcld';"

FILENAME="$final_target_path/nxtcld_bkup-$(date +%-Y%-m%-d)-$(date +%-T).tar.gz"
cd $final_target_path
tar -cpzf $FILENAME $int_target_path

# print back up size
echo "nc_backup size: $(stat --printf='%s' $FILENAME | numfmt --to=iec)"

# stop all services
/usr/sbin/service nginx stop
/usr/sbin/service mysql stop
/usr/sbin/service redis-server stop
/usr/sbin/service php7.3-fpm stop

# remove copied files
rm -r $int_target_path

# if ModSecurity is enabled remove the '#'
#echo "+---------+-------+--------------+"
#echo "|   ModeSec Access denied        |"
#echo "+---------+-------+--------------+"
#/bin/cat /var/log/nginx/error.log /var/log/nginx/error.log.1  | egrep -i "access denied" | egrep -i "id \"[0-9]{6}\"" -o | sort | uniq -c | sort -nr
#echo "+---------+-------+--------------+"
#echo "|   ModeSec Warnings             |"
#echo "+---------+-------+--------------+"
#/bin/cat /var/log/modsec_audit.log | egrep -i "warning\." | egrep -i "id \"[0-9]{6}\"" -o | sort | uniq -c | sort -nr
#echo "+---------+-------+--------------+"

# restart all services
/usr/sbin/service nginx stop
/usr/sbin/service mysql restart
/usr/sbin/service redis-server restart

# enable if Collabora and/or OnlyOffice are used
#/usr/bin/docker restart COLLABORAOFFICE
#/usr/bin/docker restart ONLYOFFICE

/usr/sbin/service php7.3-fpm restart
/usr/sbin/service nginx restart

# disable maintanance mode
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off

# Nextcloud optimizations
/root/optimize.sh

# check for Nextcloud updates
echo "Nextcloud apps are checked for updates..."
/root/upgrade.sh

# print end date/time
echo "END: $(date)"

# substitute your.name@dedyn.io properly to send backup status mails and enable it
#mail -s "Backup - $(date +$CURRENT_TIME_FORMAT)" -a "FROM: Your Name <your.name@dedyn.io>" your.name@dedyn.io < /path/to/your/logfile
cd /
umount /bkup

exit 0