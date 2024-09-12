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

# Create log files and set permissions
RUN touch /var/log/cron.log /var/log/mikrotik_backup.log && \
    chmod 0644 /var/log/cron.log /var/log/mikrotik_backup.log && \
    chown backupuser:backupuser /var/log/cron.log /var/log/mikrotik_backup.log

# Create a startup script
COPY <<EOF /start.sh
#!/bin/sh
echo "Starting container..."
if [ -f /home/backupuser/.ssh/id_rsa ]; then
  chmod 600 /home/backupuser/.ssh/id_rsa
  chown backupuser:backupuser /home/backupuser/.ssh/id_rsa
  echo "SSH key permissions set"
fi
if [ -n "$MIKROTIK_ROUTER" ]; then
  ssh-keyscan -H $MIKROTIK_ROUTER >> /home/backupuser/.ssh/known_hosts
  chown backupuser:backupuser /home/backupuser/.ssh/known_hosts
  chmod 644 /home/backupuser/.ssh/known_hosts
  echo "Added $MIKROTIK_ROUTER to known_hosts"
fi
if [ -n "$TZDATA" ]; then
  ln -snf /usr/share/zoneinfo/$TZDATA /etc/localtime && echo $TZDATA > /etc/timezone
  echo "Timezone set to $TZDATA"
fi
# Export all environment variables
export $(printenv | sed 's/=.*//' | grep -v '^$' | grep -v '^_' | tr '\n' ' ')
# Create cron job
echo "$CRON_SCHEDULE /bin/bash -c '/home/backupuser/mikrotik_backup.sh' >> /var/log/mikrotik_backup.log 2>&1" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root
echo "Cron job set up with schedule: $CRON_SCHEDULE"
echo "Starting cron service..."
crond -f -d 8
EOF

RUN chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]