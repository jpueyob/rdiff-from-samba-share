#!/bin/bash
#differential backup from samba share with rdiff-backup
#jpueyob - dibanezg
#Creates a log file where you can find the results of a operation
#If something goes wrong it exits with 1.
#Requires rdiff-backup. Tested on CentOS 6.4

#Samba share vars
SERVER_IP='192.168.1.1'
SERVER_SHARE='sharename'
MOUNT_OPTIONS='user=SambaUser,password=,uid=1000,gid=100'
#local directories vars
MOUNT_POINT='/mnt/ShareName'
BACKUP_DIR='/Backup/BackupName'
LOG_FILE='/var/log/backupShare.log'
LOCK_FILE='/tmp/BackupShare.blk'
#sync control if server share is empty.
#valid values "yes" or "no"
SYNC_IF_EMPTY="no"

#write_output writes the output to a log file.
function write_output
{
   _LOG="$_LOG\n$1"
   _LOG="$_LOG\nEnd of operations: `date '+%D %X'`"
   _LOG="$_LOG\n--------------------------------------------------------\n"
   echo -e $_LOG >> $LOG_FILE
}

#controlling existance of BACKUP_DIR
if [ ! -d $BACKUP_DIR ]; then
   write_output "ERROR\nDestiny dir $BACKUP_DIR does not exist."
   exit 1
fi

#Controlling umount
if [ -f $LOCK_FILE ]; then
   write_output "ERROR\nBackup proccess of $BACKUP_DIR already running."
   exit 1
fi

#Starting log and blocking to avoid duplication of the proccess
_LOG="Process start: `date '+%D %X'`"
touch $LOCK_FILE

#mounting network share
mount -t cifs //$SERVER_IP/$SERVER_SHARE $MOUNT_POINT -o $MOUNT_OPTIONS
if [ $? -ne 0 ]; then
   write_output "ERROR\nCant mount $MOUNT_POINT"
   rm -rf $LOCK_FILE
   exit 1
fi

#Empty source dir control. If you want to sync a empty samba share change value on $SYNC_IF_EMPTY.
if [ "$(ls -A $MOUNT_POINT 2> /dev/null)" == "" ] && [ $SYNC_IF_EMPTY == "no" ]; then
   write_output "ERROR\nUnable to sync $MOUNT_POINT. Sync from empty source NOT allowed"
   rm -rf $LOCK_FILE
   exit 1
fi

#rdiff-backup BACKUP_DIR
rdiff-backup $MOUNT_POINT $BACKUP_DIR
if [ $? -ne 0 ]; then
   write_output "ERROR\nError while sync of $MOUNT_POINT"
   rm -rf $LOCK_FILE
   exit 1
fi

#Cleaning old backups
rdiff-backup --remove-older-than 7B $BACKUP_DIR
if [ $? -ne 0 ]; then
   write_output "ERROR\nError deleting old backups"
   umount -f $MOUNT_POINT
   rm -rf $LOCK_FILE
   exit 1
fi

#Umounting network share
umount $MOUNT_POINT
if [ $? -ne 0 ]; then
   write_output "ERROR\nUnable to umount $MOUNT_POINT\nForcing umount..."
   umount -f $MOUNT_POINT
   rm -rf $LOCK_FILE
   exit 1
fi

#Everything ok
write_output "OPERATIONS SUCCESSFULLY COMPLETED"
rm -rf $LOCK_FILE
exit 0

