#!/bin/bash

# Copyright (c) 2020 Simon Lindner (https://github.com/szaimen)

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This file incorporates work covered by the following copyright and  
# permission notice: 

    # Copyright (c) 2017 DecaTec (https://decatec.de)

    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:

    # The above copyright notice and this permission notice shall be included in all
    # copies or substantial portions of the Software.

    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    # SOFTWARE.

# Functions
message() {
    whiptail --msgbox "$1" "" ""
}
occ() {
    sudo -u www-data php /var/www/nextcloud/occ "$@"
}
installed() {
    if dpkg -s "$1" | grep -q "^Status: install ok installed$"; then
        return 0
    else
        return 1
    fi
}
user_question() {
    while true; do 
        read -p "$1 ([y]es or [n]o): " ANSWER
        if [ "$ANSWER" = no ] || [ "$ANSWER" = n ]; then
            echo "no" && break
        elif [ "$ANSWER" = yes ] || [ "$ANSWER" = y ]; then
            echo "yes" && break
        fi
    done
}

# Variables
BITWARDEN_PATH="/home/bitwarden_rs"

# check if whiptail is installed
if ! installed whiptail; then
    echo "It seems like whiptail is not installed. This is not supported."
    exit 1
fi

# Rootcheck
if [ "$EUID" -ne 0 ]; then
    message "You are not root. Please run 'sudo bash migration.sh'"
    exit 1
fi

# Check if Backup is possible

if [ ! -f "/var/www/nextcloud/occ" ]; then
    message "It seems like your Nextcloud is not installed in /var/www/nextcloud.\nThis is not supported."
    exit 1
fi

# Check webserveruser
WEBUNAME=$(ls -l /var/www/nextcloud/occ | awk '{print $4}')
if [ "$WEBUNAME" != "www-data" ]; then 
    message "It seems like your webserveruser is not www-data.\nThis is not supported."
    exit 1
fi

# At least Nextcloud 18 is needed
VERSION=$(occ config:system:get version)
if [ "${VERSION%%.*}" -lt "18" ]; then
    message "You are not on Nextcloud 18 or higher.\nPlease upgrade to Nextcloud 18 before you can continue."
    exit 1
fi

# Check OS_ID
if [ "$(lsb_release -is)" != "Ubuntu" ]; then
    message "This script is only meant to run on Ubuntu.\nThis is not supported"
    exit 1
fi

# Check OS_Codename
if [ "$(lsb_release -cs)" != "bionic" ]; then
    message "This script is only meant to run on Ubuntu version 18.04.\nThis is not supported"
    exit 1
fi

# Check if datadirectory is mnt-ncdata
if [ "$(occ config:system:get datadirectory)" != "/mnt/ncdata" ]; then   
    message "It seems like your NCDATA-path is not /mnt/ncdata.\nThis is not supported."
    exit 1
fi

# Check if dbtype is pgsql
if [ "$(occ config:system:get dbtype)" != "pgsql" ]; then
    message "It seems like your dbtype is not postgresql.\nThis is not supported."
    exit 1
fi

# Check if dbname is nextcloud_db
if [ "$(occ config:system:get dbname)" != "nextcloud_db" ]; then
    message "It seems like your dbname is not nextcloud_db.\nThis is not supported."
    exit 1
fi

# Check if dbuser is ncadmin
if [ "$(occ config:system:get dbuser)" != "ncadmin" ]; then
    message "It seems like your dbuser is not ncadmin.\nThis is not supported."
    exit 1
fi

# Check if apache2 is installed
if ! installed apache2; then
    message "It seems like your webserver is not apache2.\nThis is not supported."
    exit 1
fi

# Check if php7.2 is installed
if ! installed php7.2-fpm || installed php7.3-fpm || installed php7.4-fpm; then
    message "It seems like php7.2 is not installed or any other php version is additionally installed.\nThis is not supported."
    exit 1
fi

# Backup of Bitwarden in the old place is not supported.
if [ -d "/root/bwdata/" ] || [ -d "/home/bitwarden/bwdata/" ]; then
    message "It seems like the official Bitwarden is or was installed.\This is not supported."
    exit 1  
fi

if [ -d "$BITWARDEN_PATH" ]; then
    if [ ! -f "$BITWARDEN_PATH"/config.json ]; then
        message "It seems like there is no config.json file for Bitwarden_rs.\This is not supported."
        exit 1  
    fi
    BITWARDEN="yes"
fi

# Get smb-mountpoint
if mountpoint /mnt/smbshares/1 -q; then
    SMB_MOUNT=/mnt/smbshares/1
elif mountpoint /mnt/smbshares/2 -q; then
    SMB_MOUNT=/mnt/smbshares/2
elif mountpoint /mnt/smbshares/3 -q; then
    SMB_MOUNT=/mnt/smbshares/3
fi

# Check if SMB-share is mounted
if [ -z "$SMB_MOUNT" ]; then
    message "No SMB-share mounted. Please do that by running the smbmount script before you can continue."
    exit 1
fi

# Inform the user what the script does
message "This script is only meant for migrating from one Nextcloud VM based on Ubuntu 18.04 to another Nextcloud VM based on Ubuntu 20.04."
if [ $(user_question "Do you want to continue?") = "no" ]; then
    echo "exiting" && exit 1
fi

# Select backupdirectory
while true; do
    backupMainDir=$(whiptail --inputbox "Do you want to change the folder inside the SMBmount?\nOtherwise just hit [ENTER]" "" "" "$SMB_MOUNT/ncbackup" 3>&1 1>&2 2>&3)
    if [ $(user_question "Do you want to take $backupMainDir?") = "no" ]; then
        message "It seems like the user you weren't satisfied by the chosen path ($backupMainDir) Please try again."
    else
        if ! echo "$backupMainDir" | grep -q /mnt/smbshares; then
            message "Other backup directories than SMB-mounts aren't supported. Please try again."
        else
            echo "Backup directory: $backupMainDir" && break
        fi
    fi
done

mkdir -p "$backupMainDir"

backupdir="${backupMainDir}/"

nextcloudFileDir="/var/www/nextcloud"

message "Do you want to backup the datadir /mnt/ncdata? Default is yes."
if [ $(user_question "Do you want to backup the datadir?") = "yes" ]; then
    nextcloudDataDir="/mnt/ncdata"
else
    nextcloudDataDir="no"
fi

webserverServiceName='apache2'

webserverUser='www-data'

databaseSystem='postgresql'

nextcloudDatabase='nextcloud_db'

dbUser='ncadmin'

dbPassword=$(occ config:system:get dbpassword)

instanceID=$(occ config:system:get instanceid)

redisPassword=$(occ config:system:get redis password)

fileNameBackupFileDir='nextcloud-filedir.tar.gz'
fileNameBackupDataDir='nextcloud-datadir.tar.gz'
fileNameBitwarden='bitwarden.tar.gz'

fileNameBackupDb='nextcloud-db.sql'

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

function DisableMaintenanceMode() {
	echo "Switching off maintenance mode..."
	occ maintenance:mode --off
	echo "Done"
	echo
}

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	read -p "Backup cancelled. Keep maintenance mode? [y/n] " -n 1 -r
	echo

	if ! [[ $REPLY =~ ^[Yy]$ ]]; then
		DisableMaintenanceMode
	else
		echo "Maintenance mode still enabled."
	fi

	exit 1
}

# Set maintenance mode
echo "Set maintenance mode for Nextcloud..."
occ maintenance:mode --on
echo "Done"

# Stop web server
echo "Stopping web server..."
systemctl stop "${webserverServiceName}"
echo "Done"

# Backup file directory
echo "Creating backup of Nextcloud file directory..."
tar -cpzf "${backupdir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
echo "Done"

# Backup data directory
if [ "$nextcloudDataDir" != "no" ]; then
    echo "Creating backup of Nextcloud data directory..."
    tar -cpzf "${backupdir}${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .
    #tar -cpzf "${backupdir}${fileNameBackupDataDir}" --exclude="./appdata_${instanceID}/preview" -C "${nextcloudDataDir}" .
    echo "Done"
fi

# Backup DB
echo "Backup Nextcloud database (PostgreSQL)..."
PGPASSWORD="${dbPassword}" pg_dump "${nextcloudDatabase}" -h localhost -U "${dbUser}" -f "${backupdir}/${fileNameBackupDb}"
echo "Done"

# Backup Bitwarden in new place
if [ "$BITWARDEN" = "yes" ]; then
    echo "Backing up Bitwarden_rs"
    docker stop bitwarden_rs
    tar -cpzf "${backupdir}/${fileNameBitwarden}" --exclude="./bitwarden.log" -C "$BITWARDEN_PATH" .
    docker start bitwarden_rs
    echo "Done"
fi

# Backing up update.sh to have the data if it was modified
echo "Backing up update.sh..."
mkdir -p "$backupdir/no-restore"
cp "/var/scripts/update.sh" "$backupdir/no-restore"
echo "Done"

# Backing up crontab to have the data if it was modified
echo "Backing up crontabs..."
cp -R /var/spool/cron/crontabs "$backupdir/no-restore"
cp /etc/crontab "$backupdir/no-restore"
echo "Done"

# Backing up fstab to have the data if it was modified
echo "Backing up fstab..."
cp /etc/fstab "$backupdir/no-restore"
echo "Done"

# Start web server
echo "Starting web server..."
systemctl start "${webserverServiceName}"
echo "Done"

# Disable maintenance mode
occ maintenance:mode --off

#-----------------------------------------------creating restore.sh-file--------------------------------------------------

cat > ${backupdir}/restore.sh <<- EOF
#!/bin/bash

# Copyright (c) 2020 Simon Lindner (https://github.com/szaimen)

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# This file incorporates work covered by the following copyright and  
# permission notice: 

    # Copyright (c) 2017 DecaTec (https://decatec.de)

    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to deal
    # in the Software without restriction, including without limitation the rights
    # to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:

    # The above copyright notice and this permission notice shall be included in all
    # copies or substantial portions of the Software.

    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    # AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    # LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    # OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    # SOFTWARE.

# Variables
SCRIPT_DIR=\$(dirname \$BASH_SOURCE)
#SCRIPT_NAME=\$(basename \$BASH_SOURCE)
#SCRIPT_PATH=\$BASH_SOURCE

# Functions
message() {
    whiptail --msgbox "\$1" "" ""
}
occ() {
    sudo -u www-data php /var/www/nextcloud/occ "\$@"
}
installed() {
    if dpkg -s "\$1" | grep -q "^Status: install ok installed$"; then
        return 0
    else
        return 1
    fi
}
user_question() {
    while true; do 
        read -p "\$1 ([y]es or [n]o): " ANSWER
        if [ "\$ANSWER" = no ] || [ "\$ANSWER" = n ]; then
            echo "no" && break
        elif [ "\$ANSWER" = yes ] || [ "\$ANSWER" = y ]; then
            echo "yes" && break
        fi
    done
}

# install whiptail if not already installed
if ! installed whiptail; then
    echo "It seems like whiptail is not installed. This is not supported."
    exit 1
fi

# Rootcheck
if [ "\$EUID" -ne 0 ]; then
    message "You are not root. Please run 'sudo bash restore.sh'"
    exit 1
fi

# Check if Restoring is possible

if [ ! -f "/var/www/nextcloud/occ" ]; then
    message "It seems like the default Nextcloud is not installed in /var/www/nextcloud.\nThis is not supported."
    exit 1
fi

# Check if activate-tls exists
if [ ! -f /var/scripts/activate-tls.sh ]; then
    message "It seems like you have already run the activate-tls.sh script.\nThis is not supported. Please start all over again with a new NcVM."
    exit 1
fi

# Check webserveruser
WEBUNAME=\$(ls -l /var/www/nextcloud/occ | awk '{print \$4}')
if [ "\$WEBUNAME" != "www-data" ]; then 
    message "It seems like the webserveruser is not www-data.\nThis is not supported."
    exit 1
fi

# Check OS_ID
if [ "\$(lsb_release -is)" != "Ubuntu" ]; then
    message "This script is only meant to run on Ubuntu.\nThis is not supported"
    exit 1
fi

# Check OS_Codename
if [ "\$(lsb_release -cs)" != "focal" ]; then
    message "This script is only meant to run on Ubuntu version 20.04.\nThis is not supported"
    exit 1
fi

# Check if datadirectory is mnt-ncdata
if [ "\$(occ config:system:get datadirectory)" != "/mnt/ncdata" ]; then   
    message "It seems like the default NCDATA-path is not /mnt/ncdata.\nThis is not supported."
    exit 1
fi

# Check if dbtype is pgsql
if [ "\$(occ config:system:get dbtype)" != "pgsql" ]; then
    message "It seems like the default dbtype is not postgresql.\nThis is not supported."
    exit 1
fi

# Check if dbname is nextcloud_db
if [ "\$(occ config:system:get dbname)" != "nextcloud_db" ]; then
    message "It seems like the default dbname is not nextcloud_db.\nThis is not supported."
    exit 1
fi

# Check if dbuser is ncadmin
if [ "\$(occ config:system:get dbuser)" != "ncadmin" ]; then
    message "It seems like the default dbuser is not ncadmin.\nThis is not supported."
    exit 1
fi

# Check if apache2 is installed
if ! installed apache2; then
    message "It seems like your webserver is not apache2.\nThis is not supported."
    exit 1
fi

# Check if php7.4 is installed
if ! installed php7.4-fpm; then
    message "It seems like php7.4 is not installed.\nThis is not supported."
    exit 1
fi

backupMainDir=\${SCRIPT_DIR}/

echo "Backup directory: \$backupMainDir"

currentRestoreDir=\$backupMainDir

nextcloudFileDir='$nextcloudFileDir'

nextcloudDataDir='$nextcloudDataDir'

webserverServiceName='$webserverServiceName'

webserverUser='$webserverUser'

databaseSystem='$databaseSystem'

nextcloudDatabase='$nextcloudDatabase'

redisPassword='$redisPassword'

dbUser='$dbUser'

dbPassword='$dbPassword'

fileNameBackupFileDir='$fileNameBackupFileDir'
fileNameBackupDataDir='$fileNameBackupDataDir'

fileNameBackupDb='$fileNameBackupDb'

# Check if needed files are present

# Check if db-backup is present
if [ ! -f "\${currentRestoreDir}/\${fileNameBackupDb}" ]; then
    message "Something got wrong. The db-file is not present"
    exit 1
fi

# Check if datadir-file is present
if [ "\$nextcloudDataDir" != "no" ]; then
    if [ ! -f "\${currentRestoreDir}/\${fileNameBackupDataDir}" ]; then
        message "Something got wrong. The datadir-file is not present."
        exit 1
    fi
fi

# Check if nextclouddir-file is present
if [ ! -f "\${currentRestoreDir}/\${fileNameBackupFileDir}" ]; then
    message "Something got wrong. The nextclouddir-file is not present."
    exit 1
fi

# Inform the user
message "This script will restore the files of a backed up Nextcloud VM and delete the files and database of the current instance.
Please Note: this restore.sh file has to be in the same directory with $fileNameBackupFileDir, $fileNameBackupDb and possibly $fileNameBackupDataDir."
if [ \$(user_question "So do you want to continue?") = "no" ]; then
    echo "exiting" && exit 1
fi

# Function for error messages
errorecho() { cat <<< "\$@" 1>&2; }

# Check if backup dir exists
if [ ! -d "\${currentRestoreDir}" ]; then
	errorecho "ERROR: Backup \${currentRestoreDir} not found!"
    exit 1
fi

# Check if the commands for restoring the database are available
if ! [ -x "\$(command -v psql)" ]; then
    errorecho "ERROR: PostgreSQL not installed (command psql not found)."
    errorecho "ERROR: No restore of database possible!"
    errorecho "Cancel restore"
    exit 1
fi

# Set maintenance mode
echo "Set maintenance mode for Nextcloud..."
occ maintenance:mode --on
echo "Done"

# Stop web server
echo "Stopping web server..."
systemctl stop "\${webserverServiceName}"
echo "Done"

# Delete old Nextcloud directories

# File directory
echo "Deleting old Nextcloud file directory..."
rm -r "\${nextcloudFileDir}"
mkdir -p "\${nextcloudFileDir}"
echo "Done"

# Data directory
if [ "\$nextcloudDataDir" != "no" ]; then
    echo "Deleting old Nextcloud data directory..."
    set +e
    rm -r "\${nextcloudDataDir}" &>/dev/null
    set -e
    echo "Done"
fi

# Restore file and data directory

# File directory
echo "Restoring Nextcloud file directory..."
tar -xzf "\${currentRestoreDir}/\${fileNameBackupFileDir}" -C "\${nextcloudFileDir}"
echo "Done"

# Data directory
if [ "\$nextcloudDataDir" != "no" ]; then
    echo "Restoring Nextcloud data directory..."
    tar -xzf "\${currentRestoreDir}/\${fileNameBackupDataDir}" -C "\${nextcloudDataDir}"
    echo "Done"
fi

# Restore database
echo "Dropping old Nextcloud DB..."
sudo -Hiu postgres psql \${nextcloudDatabase} -c "ALTER USER \${dbUser} WITH PASSWORD '\${dbPassword}'"
sudo -Hiu postgres psql -c "DROP DATABASE \${nextcloudDatabase};"
echo "Done"

echo "Creating new DB for Nextcloud..."
sudo -Hiu postgres psql -c "CREATE DATABASE \${nextcloudDatabase} WITH OWNER \${dbUser} TEMPLATE template0 ENCODING \"UTF8\";"
echo "Done"

echo "Restoring backup DB..."
sudo -Hiu postgres psql "\${nextcloudDatabase}" < "\${currentRestoreDir}/\${fileNameBackupDb}"
echo "Done"

# Restore old redis password
sed -i "s/^requirepass.*/requirepass \$redisPassword/g" /etc/redis/redis.conf

# Start web server
echo "Starting web server..."
systemctl start "\${webserverServiceName}"
echo "Done"

# Disbale maintenance mode
echo "Switching off maintenance mode..."
occ maintenance:mode --off
echo "Done"

# Update the system data-fingerprint
echo "Updating the system data-fingerprint..."
occ maintenance:data-fingerprint
echo "Done"

## rescan appdata, if files have changed
#echo "Rescan appdata, if files have changed"
#occ files:scan-app-data
#echo "Done"

# repairing the Database, if it got corupted
echo "Repairing the Database, if it got corupted"
occ maintenance:repair 
echo "Done"

# Appending the new local IP-address to trusted Domains
echo "appending the new Ip-Address to trusted Domains"
IP_ADDR=\$(hostname -I | awk '{print $1}')
i=0
while [ "\$i" -le 10 ]; do
    if [ "\$(occ config:system:get trusted_domains "\$i")" = "" ]; then
        occ config:system:set trusted_domains "\$i" --value="\$IP_ADDR"
        break
    else
        i=\$((i+1))
    fi
done
echo "Done"

echo "The Backup should be restored at this point."
echo "Please only continue, if you see no errors above!"
if [ \$(user_question "So do you want to continue?") = "no" ]; then
    exit 1
fi

message "The Backup was successfully restored.\nThe time has come to logg in to your Nextcloud in a Browser using the ipaddress \$IP_ADDR to check if Nextcloud works as expected.\n(e.g. check the Nextcloud logs and try out all installed apps)\nIf yes, just press [ENTER]."

# Install Let's Encrypt
bash /var/scripts/activate-tls.sh

EOF

#-----------------------------------------------creating bitwarden-restore.sh-file--------------------------------------------------

if [ "$BITWARDEN" = "yes" ]; then
    cat > ${backupdir}/bitwarden-restore.sh <<- EOF
#!/bin/bash

# Copyright (c) 2020 Simon Lindner (https://github.com/szaimen)

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Variables
SCRIPT_DIR=\$(dirname \$BASH_SOURCE)
BITWARDEN_PATH="$BITWARDEN_PATH"
fileNameBitwarden="$fileNameBitwarden"

# Functions
message() {
    whiptail --msgbox "\$1" "" ""
}
user_question() {
    while true; do 
        read -p "\$1 ([y]es or [n]o): " ANSWER
        if [ "\$ANSWER" = no ] || [ "\$ANSWER" = n ]; then
            echo "no" && break
        elif [ "\$ANSWER" = yes ] || [ "\$ANSWER" = y ]; then
            echo "yes" && break
        fi
    done
}
installed() {
    if dpkg -s "\$1" | grep -q "^Status: install ok installed$"; then
        return 0
    else
        return 1
    fi
}

# install whiptail if not already installed
if ! installed whiptail; then
    echo "It seems like whiptail is not installed. This is not supported."
    exit 1
fi

# Rootcheck
if [ "\$EUID" -ne 0 ]; then
    message "You are not root. Please run 'sudo bash restore.sh'"
    exit 1
fi

message "Before you continue, please make sure, that you have Bitwarden_rs installed on the new NcVM by executing:
'sudo bash /var/scripts/menu.sh' and choose Additional Apps -> Bitwarden -> Bitwarden_rs

Please install Bitwarden_rs on the new NcVM before restoring your data with this script.
While doing this, enter as Bitwarden_rs-Domain the same Domain that you have used for Bitwarden_rs by now.

After doing this you can continue with executing this script, which will restore all your data to the new NcVM."

if [ \$(user_question "Have you already installed Bitwarden_rs?") = "no" ]; then
    echo "exiting" && exit 1
fi

# Check if bitwarden-restore.tar.gz is present
if [ ! -f "\$SCRIPT_DIR/\${fileNameBitwarden}" ]; then
    message "Something got wrong. The Bitwarden_rs Backup file is not present."
    exit 1
fi

if [ ! -d "\$BITWARDEN_PATH" ]; then
    message "Bitwarden_rs isn't installed. Please first install Bitwarden_rs based on the scripts guidance."
    exit 1
fi

# Stop Bitwarden_rs service
echo "Stopping Bitwarden_rs..."
docker stop bitwarden_rs
echo "Done"

# Remove all old files in the Bitwarden_rs directory and creating a new folder
echo "Removing all old files in the Bitwarden_rs directory and creating a new folder..."
rm -rf "\${BITWARDEN_PATH:?}"
mkdir -p "\$BITWARDEN_PATH"
echo "Done"

# Restore files to bitwarden
echo "Restoring files to the bitwarden directory..."
tar -xzf "\$SCRIPT_DIR/\${fileNameBitwarden}" -C "\${BITWARDEN_PATH}"
echo "Done"

# Start Bitwarden_rs
echo "Starting Bitwarden_rs..."
docker start bitwarden_rs
echo "Done"

message "Congratulation! Your Bitwarden_rs installation should be restore by now. Please visit your Bitwarden_rs-Domain to check if everything is okay."
exit
EOF
fi

#--------------------------------------------------------------------------------------------------------------------

# Check if db-backup was created
if [ ! -f "${backupdir}/${fileNameBackupDb}" ]; then
    message "Something got wrong. The exported database file was not created."
    exit 1
fi

# Check if datadir-file was created
if [ "$nextcloudDataDir" != "no" ]; then
    if [ ! -f "${backupdir}${fileNameBackupDataDir}" ]; then
        message "Something got wrong. The datadir-file was not created."
        exit 1
    fi
fi

# Check if nextclouddir-file was created
if [ ! -f "${backupdir}/${fileNameBackupFileDir}" ]; then
    message "Something got wrong. The nextclouddir-file was not created."
    exit 1
fi

# Check if restore.sh was created
if [ ! -f "${backupdir}/restore.sh" ]; then
    message "Something got wrong. Restore script was not created."
    exit 1
fi

# Check if bitwarden script and restore file are present
if [ "$BITWARDEN" = "yes" ]; then
    if [ ! -f "${backupdir}/${fileNameBitwarden}" ]; then
        message "Something got wrong. The Bitwarden_rs Backup file is not present."
        exit 1
    fi
    if [ ! -f "${backupdir}/bitwarden-restore.sh" ]; then
        message "Something got wrong. The Bitwarden_rs restore Script is not present."
        exit 1
    fi
fi

message "The Backup was successfully created here: ${backupdir}."
