#!/bin/bash

# Enable debugging
set -x

# This script creates a backup file on the MikroTik router, pulls it to the local machine,
# and manages the number of backup copies in a specific folder. It uses environment variables for configuration.

# Read configuration from environment variables
ROUTER="${MIKROTIK_ROUTER}"
USER="${MIKROTIK_USER}"
BACKUP_PASSWORD="${MIKROTIK_BACKUP_ENCRYPT}"
SSH_PORT="${MIKROTIK_SSH_PORT:-22}"
MAX_BACKUPS="${MIKROTIK_MAX_BACKUPS:-3}"
BACKUP_DIR="/home/backupuser/backups"

# SSH options
SSH_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i /home/backupuser/.ssh/id_rsa"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to create backup on the router
create_backup() {
    local router_command="/system backup save name=$ROUTER encryption=aes-sha256 password=$BACKUP_PASSWORD"
    echo "Executing SSH command: ssh $SSH_OPTIONS -p $SSH_PORT $USER@$ROUTER \"$router_command\""
    ssh $SSH_OPTIONS -p $SSH_PORT "$USER@$ROUTER" "$router_command"
    local ssh_exit_code=$?
    echo "SSH command exit code: $ssh_exit_code"
    if [ $ssh_exit_code -eq 0 ]; then
        echo "Backup created successfully on $ROUTER"
    else
        echo "Failed to create backup on $ROUTER"
        exit 1
    fi
}

# Function to pull backup from the router
pull_backup() {
    local backup_file="$ROUTER.backup"
    local sftp_batch_commands="get $backup_file $BACKUP_DIR/
exit"
    
    echo "Executing SFTP command: echo \"$sftp_batch_commands\" | sftp $SSH_OPTIONS -P $SSH_PORT $USER@$ROUTER"
    echo "$sftp_batch_commands" | sftp $SSH_OPTIONS -P $SSH_PORT "$USER@$ROUTER"
    local sftp_exit_code=$?
    echo "SFTP command exit code: $sftp_exit_code"
    if [ $sftp_exit_code -eq 0 ]; then
        echo "Backup file pulled successfully from $ROUTER"
    else
        echo "Failed to pull backup file from $ROUTER"
        exit 1
    fi
}

# Function to rename backup file with date stamp
rename_backup() {
    local old_name="$BACKUP_DIR/$ROUTER.backup"
    local new_name="$BACKUP_DIR/$ROUTER-$(date +%Y%m%d_%H%M%S).backup"
    echo "Renaming $old_name to $new_name"
    mv "$old_name" "$new_name"
    local mv_exit_code=$?
    echo "mv command exit code: $mv_exit_code"
    if [ $mv_exit_code -eq 0 ]; then
        echo "Backup file renamed to $(basename "$new_name")"
    else
        echo "Failed to rename backup file"
        exit 1
    fi
}

# Function to manage backup files
manage_backups() {
    local backup_count=$(ls -1 "$BACKUP_DIR/$ROUTER"-*.backup 2>/dev/null | wc -l)
    echo "Current backup count: $backup_count"
    
    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        echo "Removing old backups..."
        ls -1t "$BACKUP_DIR/$ROUTER"-*.backup | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f
        echo "Old backups removed. Keeping the $MAX_BACKUPS most recent backups."
    else
        echo "Number of backups ($backup_count) does not exceed limit ($MAX_BACKUPS). No backups deleted."
    fi
}

# Main execution
echo "Starting backup process for $ROUTER"
echo "Current environment variables:"
env | grep MIKROTIK
create_backup
pull_backup
rename_backup
manage_backups
echo "Backup process completed"

# Disable debugging
set +x