#!/bin/bash

# Redirect output to both the pipe and stdout/stderr
exec > >(tee /var/log/mikrotik_backup_pipe) 2>&1

# This script creates a backup file on the MikroTik router, pulls it to the local machine,
# and manages the number of backup copies in a specific folder. It uses environment variables for configuration.

# Read configuration from environment variables, with defaults
ROUTER=$MIKROTIK_ROUTER
USER=$MIKROTIK_USER
BACKUP_PASSWORD=$MIKROTIK_BACKUP_ENCRYPT
SSH_PORT=$MIKROTIK_SSH_PORT
MAX_BACKUPS=$MIKROTIK_MAX_BACKUPS
BACKUP_DIR="/home/backupuser/backups"
TZ="${TZDATA:-Asia/Jakarta}"

# SSH and SFTP options to bypass host key checking and accept ssh-rsa key type
SSH_OPTIONS="-o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -i /home/backupuser/.ssh/id_rsa"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

log "Starting backup process for $ROUTER"

# Function to create backup on the router
create_backup() {
    local router_command="/system backup save name=$ROUTER encryption=aes-sha256 password=$BACKUP_PASSWORD"
    log "Creating backup on router..."
    ssh $SSH_OPTIONS -p $SSH_PORT "$USER@$ROUTER" "$router_command"
    if [ $? -eq 0 ]; then
        log "Backup created successfully on $ROUTER"
    else
        log "Failed to create backup on $ROUTER"
        exit 1
    fi
}

# Function to pull backup from the router
pull_backup() {
    local backup_file="$ROUTER.backup"
    local sftp_command="get $backup_file $BACKUP_DIR/"
    
    log "Pulling backup from router..."
    sftp $SSH_OPTIONS -P $SSH_PORT "$USER@$ROUTER" <<EOF
$sftp_command
exit
EOF

    if [ $? -eq 0 ]; then
        log "Backup file pulled successfully from $ROUTER"
    else
        log "Failed to pull backup file from $ROUTER"
        exit 1
    fi
}

# Function to rename backup file with date stamp
rename_backup() {
    local old_name="$BACKUP_DIR/$ROUTER.backup"
    local new_name="$BACKUP_DIR/$ROUTER-$(TZ=$TZ date +%Y%m%d_%H%M%S).backup"
    log "Renaming backup file..."
    mv "$old_name" "$new_name"
    if [ $? -eq 0 ]; then
        log "Backup file renamed to $(basename "$new_name")"
    else
        log "Failed to rename backup file"
        exit 1
    fi
}

# Function to manage backup files
manage_backups() {
    local backup_count=$(ls -1 "$BACKUP_DIR/$ROUTER"-*.backup 2>/dev/null | wc -l)
    
    log "Managing backup files..."
    if [ "$backup_count" -gt "$MAX_BACKUPS" ]; then
        log "Removing old backups..."
        ls -1t "$BACKUP_DIR/$ROUTER"-*.backup | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f
        log "Old backups removed. Keeping the $MAX_BACKUPS most recent backups."
    else
        log "Number of backups ($backup_count) does not exceed limit ($MAX_BACKUPS). No backups deleted."
    fi
}

# Main execution
create_backup
pull_backup
rename_backup
manage_backups
log "Backup process completed successfully"