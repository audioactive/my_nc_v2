#!/bin/bash
# mount bkup disk
mount /dev/sdd1 /bkup
# enbale Maintenance Mode to prevent users from working with Nextcloud
sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
# create directory first: mkdir /backup -p
BACKUP_STORE=/bkup
# create directory first: mkdir /backup-repository -p
ARCHIVE_STORE=/bkup/bkup-repo
# declare dateformat and numbering of backups
CURRENT_TIME_FORMAT="%w"
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
# declare the backup filename
ARCHIVE_FILE="$ARCHIVE_STORE/nc_backup_$(date +$CURRENT_TIME_FORMAT).tar.gz"
# change directory
cd $BACKUP_STORE
# start rsync to back up the folders
for FOLDER in ${FOLDERS_TO_BACKUP[@]}
do
	if [ -d "$FOLDER" ];
	then
		echo "Copying $FOLDER..."
		rsync -AaRx --delete $FOLDER $BACKUP_STORE
	else
		echo "Skipping $FOLDER (does not exist!)"
	fi
done
# copy the fstab
[ -f /etc/fstab ] && cp /etc/fstab $BACKUP_STORE/etc/
# copy the mail configuration
[ -f /etc/msmtprc ] && cp /etc/msmtprc $BACKUP_STORE/etc/
# create a database back up
mysqldump --single-transaction -hlocalhost -uheman -p`H3m4n@db` nxtcld > $BACKUP_STORE/ncdb_`date +"%w"`.sql
# print the database backup size
mysql -hlocalhost -uheman -p`H3m4n@db` -e "SELECT table_schema 'DB',round(sum(data_length+index_length)/1024/1024,1) 'Size (MB)' from information_schema.tables WHERE table_schema = 'nxtcld';"
# create the directories
mkdir -p $(dirname $ARCHIVE_FILE)
# compress all data
tar -cpzf $ARCHIVE_FILE .
# print back up size
echo "nc_backup size: $(stat --printf='%s' $ARCHIVE_FILE | numfmt --to=iec)"
# stop all services
/usr/sbin/service nginx stop
/usr/sbin/service mysql stop
/usr/sbin/service redis-server stop
/usr/sbin/service php7.3-fpm stop
# remove copied files 
[ -f $BACKUP_STORE/ncdb_`date +"%w"`.sql ] && rm -f $BACKUP_STORE/ncdb_`date +"%w"`.sql
[ -f /etc/msmtprc ] && rm -f $BACKUP_STORE/etc/msmtprc
[ -f /etc/fstab ] && rm -f $BACKUP_STORE/etc/fstab
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
umount /dev/sdd1
exit 0