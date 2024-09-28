#!/bin/bash
LATEST_VERSION_URL="https://download.nextcloud.com/server/releases/latest.tar.bz2"
NEXTCLOUD_PATH="/var/www/nextcloud"
PREVIOUS_VERSION=$(sudo -u www-data php $NEXTCLOUD_PATH/occ -V | awk '{print $2}')
UPDATE_INFO="$(sudo -u www-data php /var/www/nextcloud/updater/updater.phar)"
NEXTCLOUD_PATH_OLD="/var/www/nextcloud_backups/nextcloud_$PREVIOUS_VERSION"
SIGNATURE_URL="https://download.nextcloud.com/server/releases/latest.tar.bz2.asc"
KEYS_URL="https://nextcloud.com/nextcloud.asc"

check_root() {
	if [ "$(id -u)" != "0" ]; then
		echo "Script must be executed as root"
		echo "Re-runnig with sudo..."
		sudo /bin/bash "$0" "$@"
		exit $?
	fi
}

check_root "$@"


if echo $UPDATE_INFO | grep -i "No update available" ; then
	exit 0
fi

echo "Putting Nextcloud into maintance mode..."
sudo -u www-data php $NEXTCLOUD_PATH/occ maintenance:mode --on


if [ -d $NEXTCLOUD_PATH/update ] && [ -d $NEXTCLOUD_PATH/update/data ]; then
	echo "NEXTCLOUD_PATH/update/data is found. Proceeding download the latest version of the Nextcloud"
	wget $LATEST_VERSION_URL -O $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2

else
	echo "Directory is not found. Creating a new directories under $NEXTCLOUD_PATH/update/data"
	mkdir $NEXTCLOUD_PATH/update/ $NEXTCLOUD_PATH/update/data/
	wget $LATEST_VERSION_URL -O $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2
fi
echo "Downloading signature"
wget $SIGNATURE_URL -O $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2.asc
ls $NEXTCLOUD_PATH/update/data/
echo "Grabbing the keys"
wget $KEYS_URL -O- | gpg --import

echo "Verifying the signature"
gpg --verify $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2.asc $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2

if [ $? -ne 0 ]; then
	echo "GPG verification has failed" >&2
	exit 1
else
	echo "GPG verification has been successful"
fi

echo "Extracting files"
tar -xjvf $NEXTCLOUD_PATH/update/data/latest_nextcloud.tar.bz2 -C $NEXTCLOUD_PATH/update/data/

echo "Stopping  your apache2.service"
systemctl stop apache2.service

echo "Backing-up current Nextcloud version"
mv $NEXTCLOUD_PATH "/var/www/nextcloud_backups/nextcloud_$PREVIOUS_VERSION"

echo "Moving new version to /var/www"
mv $NEXTCLOUD_PATH_OLD/update/data/nextcloud/ /var/www/

echo "Copying the old config to the new version"
cp -p $NEXTCLOUD_PATH_OLD/config/config.php $NEXTCLOUD_PATH/config/

echo "Copying the old data/ to the new version"
cp -r -p $NEXTCLOUD_PATH_OLD/data/ $NEXTCLOUD_PATH/

echo "Adjusting file ownership and persmissions"
chown -R www-data:www-data $NEXTCLOUD_PATH
find  /var/www/nextcloud/ -type d -exec chmod 750 {} \;
find  /var/www/nextcloud/ -type f -exec chmod 640 {} \;

echo "Starting web browser"
systemctl start apache2.service

echo "Launching the upgrade using occ"
sudo -u www-data php $NEXTCLOUD_PATH/occ upgrade

echo "Cleaning up temporary files..."
rm $NEXTCLOUD_PATH_OLD/update/data/latest_nextcloud.tar.bz2

echo "Stopping maintance"
sudo -u www-data php $NEXTCLOUD_PATH/occ maintenance:mode --off

echo "Rescanning.."
sudo -u www-data php $NEXTCLOUD_PATH/console.php files:scan --all

