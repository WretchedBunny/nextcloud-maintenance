#!/bin/bash

DATABASE="nextcloud"

check_root() {
	if [ "$(id -u)" != "0" ]; then
		echo "Scripts must be executed as root"
		echo "Re-running with sudo"
		sudo /bin/bash "$0"
		exit $?
	fi
}

check_root  "$@"

read -p "Please enter username to the database: " USERNAME
read -p "Please enter password to the database: " -s PASSWORD

mysql -u $USERNAME -p$PASSWORD -D $DATABASE -e "SHOW TABLES;" | while read TABLE; do
	if [ "$TABLE" != "Tables_in_$TABLE" ]; then
		mysql -u $USERNAME -p$PASSWORD -D $DATABASE -e "OPTIMIZE TABLE $TABLE;"
		mysql -u $USERNAME  -p$PASSWORD -D $DATABASE -e "CHECK TABLE $TABLE;"
	fi
done
