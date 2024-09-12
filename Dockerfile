# Use Alpine 3.20 as the base image
FROM alpine:3.20

# Set the maintainer
LABEL maintainer="yoga.november2000@gmail.com"

# Install necessary packages
RUN apk add --no-cache \
    openssh-client \
    tzdata \
    logrotate \
    bash \
    coreutils 

# Set up a non-root user
RUN adduser -D backupuser
WORKDIR /home/backupuser

# Create .ssh directory and backups directory with correct permissions
RUN mkdir -p /home/backupuser/.ssh /home/backupuser/backups && \
    chmod 700 /home/backupuser/.ssh && \
    chown -R backupuser:backupuser /home/backupuser

# Add logrotate configuration
COPY logrotate.conf /etc/logrotate.d/mikrotik-backup

# Copy the backup script
COPY mikrotik_backup.sh /home/backupuser/
RUN chmod +x /home/backupuser/mikrotik_backup.sh

# Set default environment variables
ENV MIKROTIK_ROUTER=10.1.1.127 \
    MIKROTIK_USER=admin \
    MIKROTIK_BACKUP_ENCRYPT=PASSWORD \
    MIKROTIK_SSH_PORT=22 \
    MIKROTIK_MAX_BACKUPS=3 \
    TZDATA=Asia/Jakarta \
    CRON_SCHEDULE="0 0 * * *"

# Create log file and set permissions
RUN touch /var/log/mikrotik_backup.log && \
    chmod 0644 /var/log/mikrotik_backup.log && \
    chown backupuser:backupuser /var/log/mikrotik_backup.log

# Create a startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]