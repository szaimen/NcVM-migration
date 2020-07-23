# NcVM-migration.sh
A shell script for migrating the [NcVM](https://github.com/nextcloud/vm) between different Ubuntu Versions.

**Please note:** You are free to run this script at your personal risk. I am not responsible for any damaged systems and will not provide any personal support. So please keep backups!

## How to run?
Connect to your NcVM via ssh and run:
`wget https://raw.githubusercontent.com/szaimen/NcVM-migration.sh/master/migration.sh && sudo bash migration.sh`
That's it!

## How does it work?
- The whole backup-restore functionality is based on the great scripts provided by DecaTec, please see here: https://codeberg.org/DecaTec/Nextcloud-Backup-Restore
- The migration.sh script produces automatically the backup files and a restore.sh script, which can be called from the new NcVM after running the startup-scrip and restores all Nextcloud-relevant files and data, which is the database, the datadirectory and the Nextcloud-folder to the new NcVM.
- In the last step of the restore.sh script, are you asked if you want to activate tls on the new server, which is the only step left, to make the new server work again.
- After that, you can simply execute the by the NcVM provided scripts again, to get additional apps working again.

## In a nutshell
1. Create a backup of your NcVM
2. Mount a SMB-share to your NcVM using the built-in smbmount script by running<br/>`sudo bash /var/scripts/menu.sh` -> `Additional Apps` -> `SMB-mount`
3. [Execute](#how-to-run) the migration.sh script
4. [Download](https://www.hanssonit.se/nextcloud-vm/) a new NcVM
5. Import and start the new NcVM and run the startup-script **without** activating lets encrypt and tls.
6. Mount the same SMB-share to the new NcVM using the built-in smbmount script again (see point 2)
7. Execute the by the migration.sh script produced restore.sh script on the new NcVM
8. Logg in to the restored Nextcloud using the local ipaddress of the new NcVM in a Browser and test if everything works as expected<br/>(e.g. check the Nextcloud logs, test all installed Nextcloud apps, etc.)
9. If yes, enable lets encrypt by running `sudo bash /var/scripts/activate-tls.sh`
10. If needed, manually restore crontab entries, fstab entries, etc.
11. Reinstall NcVM apps by running `sudo bash /var/scripts/menu.sh` -> `Additional Apps`
12. This should be it 🎉

## Limitations
- You have to connect a SMB-mount by executing the by the NcVM provided smbmount script before running both - migration.sh & restore.sh - scripts since you need to store the backup files outside of the NcVM to be able to restore them to a new NcVM afterwards.
- If you have mounted and used SMB-mounts in the NcVM before, you need to restore them manually in the correct order at the correct mountpoint before executing the restore.sh scipt
- The migration.sh script only works on NcVM based machines with Ubuntu 18.04 and php 7.2 and the restore.sh script only works on NcVM based machines with Ubuntu 20.04 and php 7.4.
- Only the default NcVM configuration is supported.
- At least Nextcloud 18 is needed to run the migration.sh script
- Apps, that are provided by the NcVM and were installed on your old system will not be automatically installed by the restore.sh script, since they can get easily reinstalled by running the by the NcVM provided scripts.
- Non-standard customization on the old NcVM will not get backed up and restored, and has to get manually redone on the new NcVM after restoring.
- The crontabs are saved in a no-restore folder. They are backed up here, so that you can look at them to better remember which cronjobs where running in your old system. You need to manually restore missing cronjobs, since that can't be automated.
- The update.sh file is backed up in this folder, as well, since you could possibly have changed something in there, which has to get manually restored, if needed.
- The fstab is also getting backed up in the no-restore folder so that you can see your old configuration, which is helpful e.g. to be able to manually restore the correct order of smb-mounts, etc.
- Backup of bitwarden data is not supported.
