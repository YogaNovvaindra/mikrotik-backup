#!/bin/bash

# This script creates a backup file on the MikroTik router, pulls it to the local machine,
# and manages the number of backup copies in a specific folder. It uses environment variables for configuration.

# Read configuration from environment variables, with defaults
ROUTER="${MIKROTIK_ROUTER:-10.1.1.127}"
USER="${MIKROTIK_USER:-admin}"
BACKUP_PASSWORD="${MIKROTIK_BACKUP_ENCRYPT:-PASSWORD}"
SSH_PORT="${MIKROTIK_SSH_PORT:-22}"
MAX_BACKUPS="${MIKROTIK_MAX_BACKUPS:-3}"
BACKUP_DIR="./backups"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to create backup on the router
create_backup() {
    local router_command="/system backup save name=$ROUTER encryption=aes-sha256 password=$BACKUP_PASSWORD"
    ssh -p $SSH_PORT "$USER@$ROUTER" "$router_command"
    if [ $? -eq 0 ]; then
        echo "Backup created successfully on $ROUTER"
    else
        echo "Failed to create backup on $ROUTER"
        exit 1
    fi
}

# Function to pull backup from the router
pull_backup() {
    local backup_file="$ROUTER.backup"
    local sftp_command="get $backup_file $BACKUP_DIR/"
    
    sftp -P $SSH_PORT "$USER@$ROUTER" <<EOF
$sftp_command
exit
EOF

    if [ $? -eq 0 ]; then
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
    mv "$old_name" "$new_name"
    if [ $? -eq 0 ]; then
        echo "Backup file renamed to $(basename "$new_name")"
    else
        echo "Failed to rename backup file"
        exit 1
    fi
}

# Function to manage backup files
manage_backups() {
    local backup_count=$(ls -1 "$BACKUP_DIR/$ROUTER"-*.backup 2>/dev/null | wc -l)
    
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
create_backup
pull_backup
rename_backup
manage_backups
echo "Backup process completed successfully"