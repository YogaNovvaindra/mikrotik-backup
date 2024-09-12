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
RUN echo '#!/bin/sh' > /start.sh && \
    echo 'echo "Starting container..."' >> /start.sh && \
    echo 'if [ -f /home/backupuser/.ssh/id_rsa ]; then' >> /start.sh && \
    echo '  chmod 600 /home/backupuser/.ssh/id_rsa' >> /start.sh && \
    echo '  chown backupuser:backupuser /home/backupuser/.ssh/id_rsa' >> /start.sh && \
    echo '  echo "SSH key permissions set"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ -n "$MIKROTIK_ROUTER" ]; then' >> /start.sh && \
    echo '  ssh-keyscan -H $MIKROTIK_ROUTER >> /home/backupuser/.ssh/known_hosts' >> /start.sh && \
    echo '  chown backupuser:backupuser /home/backupuser/.ssh/known_hosts' >> /start.sh && \
    echo '  chmod 644 /home/backupuser/.ssh/known_hosts' >> /start.sh && \
    echo '  echo "Added $MIKROTIK_ROUTER to known_hosts"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ -n "$TZDATA" ]; then' >> /start.sh && \
    echo '  ln -snf /usr/share/zoneinfo/$TZDATA /etc/localtime && echo $TZDATA > /etc/timezone' >> /start.sh && \
    echo '  echo "Timezone set to $TZDATA"' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'printenv | sed "s/^\(.*\)$/export \1/g" > /home/backupuser/container_env' >> /start.sh && \
    echo 'chmod +x /home/backupuser/container_env' >> /start.sh && \
    echo 'echo "$CRON_SCHEDULE /bin/bash -c '"'"'source /home/backupuser/container_env && /home/backupuser/mikrotik_backup.sh'"'"' >> /var/log/mikrotik_backup.log 2>&1" > /etc/crontabs/root' >> /start.sh && \
    echo 'chmod 0644 /etc/crontabs/root' >> /start.sh && \
    echo 'echo "Cron job set up with schedule: $CRON_SCHEDULE"' >> /start.sh && \
    echo 'echo "Starting cron service..."' >> /start.sh && \
    echo 'crond -f -d 8' >> /start.sh && \
    chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]