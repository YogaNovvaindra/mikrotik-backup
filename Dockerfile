# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages
RUN apt-get update && apt-get install -y \
    openssh-client \
    cron \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Set up a non-root user
RUN useradd -m backupuser
WORKDIR /home/backupuser

# Create .ssh directory with correct permissions
RUN mkdir -p /home/backupuser/.ssh && \
    chmod 700 /home/backupuser/.ssh && \
    chown backupuser:backupuser /home/backupuser/.ssh 

# Copy the backup script
COPY mikrotik_backup.sh .
RUN chmod +x mikrotik_backup.sh

# Set environment variables (these can be overridden at runtime)
ENV MIKROTIK_ROUTER=10.1.1.127
ENV MIKROTIK_USER=admin
ENV MIKROTIK_BACKUP_ENCRYPT=PASSWORD
ENV MIKROTIK_SSH_PORT=22
ENV MIKROTIK_MAX_BACKUPS=3
ENV TZ=Asia/Jakarta
ENV CRON_SCHEDULE="0 0 * * *"

# Create a wrapper script to run the backup with environment variables
RUN echo '#!/bin/bash\n\
env - \
MIKROTIK_ROUTER=$MIKROTIK_ROUTER \
MIKROTIK_USER=$MIKROTIK_USER \
MIKROTIK_BACKUP_ENCRYPT=$MIKROTIK_BACKUP_ENCRYPT \
MIKROTIK_SSH_PORT=$MIKROTIK_SSH_PORT \
MIKROTIK_MAX_BACKUPS=$MIKROTIK_MAX_BACKUPS \
TZ=$TZ \
/home/backupuser/mikrotik_backup.sh' > /home/backupuser/run_backup.sh \
&& chmod +x /home/backupuser/run_backup.sh

# Set up cron job
RUN echo "$CRON_SCHEDULE root /home/backupuser/run_backup.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/backup-cron \
    && chmod 0644 /etc/cron.d/backup-cron

# Create the cron.log file
RUN touch /var/log/cron.log

# Create a startup script
RUN echo '#!/bin/bash\n\
if [ -f /home/backupuser/.ssh/id_rsa ]; then\n\
  chmod 600 /home/backupuser/.ssh/id_rsa\n\
  chown backupuser:backupuser /home/backupuser/.ssh/id_rsa\n\
fi\n\
if [ -n "$MIKROTIK_ROUTER" ]; then\n\
  ssh-keyscan -H $MIKROTIK_ROUTER >> /home/backupuser/.ssh/known_hosts\n\
  chown backupuser:backupuser /home/backupuser/.ssh/known_hosts\n\
  chmod 644 /home/backupuser/.ssh/known_hosts\n\
fi\n\
# Set the timezone\n\
if [ -n "$TZ" ]; then\n\
  ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone\n\
fi\n\
echo "$CRON_SCHEDULE root /home/backupuser/run_backup.sh >> /var/log/cron.log 2>&1" > /etc/cron.d/backup-cron\n\
cron\n\
tail -f /var/log/cron.log' > /start.sh \
&& chmod +x /start.sh

# Run the startup script
CMD ["/start.sh"]