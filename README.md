# NcVM-migration.sh
A shell script for migrating NcVM between different Ubuntu Versions.

**Please note:** I am not responsible for any damaged systems and will not provide any personal support. So please keep backups!

## How to run?
Connect to your NcVM via ssh and run:
`wget https://raw.githubusercontent.com/szaimen/NcVM-migration.sh/master/migration.sh && sudo bash migration.sh`
That's it!

## How does it work?
- The whole backup-restore functionality is based on the great scripts provided by DecaTec, please see here: https://codeberg.org/DecaTec/Nextcloud-Backup-Restore
- The migration script produces automatically a restore.sh script, which can be called from the new NcVM after running the startup-scrip and restores all Nextcloud-relevant files and data, which is the database, the datadirectory and the Nextcloud-folder to the new VM.
- In the last step of the restore.sh script, are you asked if you want to activate tls on the new server, which is the only step left, to make the new server work again.
- After that, you can simply execute the by the NcVM provided scripts again, to get additional apps working again.

## Limitations
- You have to connect an SMB-mount by executing the by the NcVM provided smbmount script before running both - migration.sh & restore.sh - scripts since you need to store the backup files outside of the VM to be able to restore them to a new VM afterwards.
- The migration.sh script only works on NcVM based machines with Ubuntu 18.04 and php 7.2 and the restore.sh script only works on NcVM based machines with Ubuntu 20.04 and php 7.4.
- Only the default NcVM configuration is supported.
- At least Nextcloud 18 is needed to run the migration.sh script
- Apps, that are provided by the VM and were installed on your old system will not be automatically installed by the restore.sh script, since they can get easily reinstalled by running the by the NcVM provided scripts.
- Non-standard customization on the old NcVM will not get backed up and restored, and has to get manually redone on the new NcVM after restoring.
- The crontabs are saved in a no-restore folder. They are backed up here, so that you can look at them to better remember which cronjobs where running in your old system. You need to manually restore missing cronjobs, since that can't be automated.
- The update.sh file is backed up in this folder, as well, since you could possibly have changed something in there, which has to get manually restored, if needed.
- The fstab is also getting backed up in the no-restore folder so that you can see your old configuration, which is helpful e.g. to be able to manually restore the correct order of smb-mounts, etc.
- Backup of bitwarden data is not supported.
