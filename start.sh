#!/bin/sh

echo "Starting container..."

if [ -f /home/backupuser/.ssh/id_rsa ]; then
  chmod 600 /home/backupuser/.ssh/id_rsa
  chown backupuser:backupuser /home/backupuser/.ssh/id_rsa
  echo "SSH key permissions set"
fi

if [ -n "$MIKROTIK_ROUTER" ]; then
  ssh-keyscan -H -t rsa,dsa,ecdsa,ed25519 $MIKROTIK_ROUTER >> /home/backupuser/.ssh/known_hosts
  chown backupuser:backupuser /home/backupuser/.ssh/known_hosts
  chmod 644 /home/backupuser/.ssh/known_hosts
  echo "Added $MIKROTIK_ROUTER to known_hosts"
fi

# Add global SSH configuration for KEX algorithms
cat << EOF > /home/backupuser/.ssh/config
Host *
    KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1,diffie-hellman-group1-sha1
EOF
chown backupuser:backupuser /home/backupuser/.ssh/config
chmod 600 /home/backupuser/.ssh/config
echo "Added global SSH configuration for KEX algorithms"

if [ -n "$TZDATA" ]; then
  ln -snf /usr/share/zoneinfo/$TZDATA /etc/localtime && echo $TZDATA > /etc/timezone
  echo "Timezone set to $TZDATA"
fi

printenv | grep -v '*' | sed "s/^\(.*\)$/export \1/g" > /home/backupuser/container_env
chmod +x /home/backupuser/container_env

echo "$CRON_SCHEDULE /bin/bash -c 'source /home/backupuser/container_env && /home/backupuser/mikrotik_backup.sh >> /var/log/mikrotik_backup.log 2>&1'" > /etc/crontabs/root
chmod 0644 /etc/crontabs/root

echo "Cron job set up with schedule: $CRON_SCHEDULE"
echo "Starting cron service..."
crond -f -d 8