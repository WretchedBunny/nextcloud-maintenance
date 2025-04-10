# nextcloud-maintenance
Automation of regular maintenance tasks for Nextcloud instance using a custom systemd service.
# Update automation script
This is first step for automated maintenance tasks for this project. To complete this step we would write program in bash scripting language.
## Variables
Firstly, we would declare some variables later.
```bash
LATEST_VERSION_URL="https://download.nextcloud.com/server/releases/latest.tar.bz2"
NEXTCLOUD_PATH="/var/www/nextcloud"
PREVIOUS_VERSION=$(sudo -u www-data php $NEXTCLOUD_PATH/occ -V | awk '{print $2}')
UPDATE_INFO="$(sudo -u www-data php /var/www/nextcloud/updater/updater.phar)"
NEXTCLOUD_PATH_OLD="/var/www/nextcloud_backups/nextcloud_$PREVIOUS_VERSION"
SIGNATURE_URL="https://download.nextcloud.com/server/releases/latest.tar.bz2.asc"
KEYS_URL="https://nextcloud.com/nextcloud.asc"

```
Here would like to mention variable **PREVIOUS_VERSION**, here we extracting previous version of the *nextcloud*(current, if no updated was issued), by calling nextcloud command line tool **occ** with **-V** flag (for version) and than extracting second filed using **awk**. In my opinion, disadvantage of such method is that we hoping that output of **occ -V** will contain version number in the second field. Nextcloud developers may change output by adding some new files, which will prevent script from right execution. This part is up to change.

The same questions can be asked to **UPDATE_INFO** variable, where we store output of command line tool *updater*. Output may not contain line, which is need to execute script.
## Privileges check
```bash
check_root() {
        if [ "$(id -u)" != "0" ]; then
                echo "Script must be executed as root"
                echo "Re-runnig with sudo..."
                sudo /bin/bash "$0" "$@"
                exit $?
        fi
}

check_root "$@"
```

^14ad1b

Here, we check for the root rights of the user. Using core utility **id**, getting user id and if it's not 0 (which is reserved for root), script will be re-executed with **sudo**.
## Update check
That's where we use **UPDATE_INFO** variable, we check if it contains *No update available* line and if yes, we stop execution.
```bash
if echo $UPDATE_INFO | grep -i "No update available" ; then
        exit 0
fi
```
## Preparation for the update
Here we put nextcloud into maintenance mode using its' command line tool and create directories for the update files.
```bash
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
```
## Verification
Here we downloading signature and check it, in order to verify credibility of files.
```bash
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
```
## Installation
```bash
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
```
## Final update steps
Here we start our web server, upgrading nextcloud, performing cleaning and general maintenance installation steps.
```bash
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
```
# Optimize the database
This is next step for automated maintenance tasks for this project. To complete this step we would write program in bash scripting language.
This is small script, so i will focus only on main part - optimization queries.
```bash
mysql -u $USERNAME -p$PASSWORD -D $DATABASE -e "SHOW TABLES;" | while read TABLE; do
        if [ "$TABLE" != "Tables_in_$TABLE" ]; then
                mysql -u $USERNAME -p$PASSWORD -D $DATABASE -e "OPTIMIZE TABLE $TABLE;"
                mysql -u $USERNAME  -p$PASSWORD -D $DATABASE -e "CHECK TABLE $TABLE;"
        fi
done
```
Here we use credentials to access DB, queering all tables of the nextcloud db by `SHOW TABLES` and then iterating through list of table names, we apply  `OPTIMIZATION`(to reorganize the physical storage of table data) query and `CHECK` (to check table for errors).
