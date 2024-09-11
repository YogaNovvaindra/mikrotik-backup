# 🔒 MikroTik Backup Docker Container

This project provides a Docker container that automates the process of creating and managing backups for MikroTik routers. It creates encrypted backups on the router, transfers them to the container, and manages the number of backup files kept.

## ✨ Features

- 🤖 Automated backups of MikroTik routers
- 🔐 Encrypted backup files
- ⏰ Configurable backup schedule
- 🗃️ Limit on the number of backup files kept
- 🌍 Timezone support
- 📝 Logging of backup operations

## 📋 Prerequisites

- 🐳 Docker and Docker Compose installed on your system
- 🔑 SSH access to your MikroTik router
- 🔐 SSH key pair for authentication

## 🚀 Quick Start

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/mikrotik-backup.git
   cd mikrotik-backup
   ```

2. Create an SSH key pair if you don't have one:
   ```
   ssh-keygen -t rsa -b 4096 -f ./id_rsa
   ```

3. Copy the public key to your MikroTik router:
   ```
   ssh admin@your_router_ip "/user ssh-keys import public-key-file=id_rsa.pub"
   ```

4. Modify the `docker-compose.yml` file to set your environment variables:
   - `MIKROTIK_ROUTER`: IP address of your MikroTik router
   - `MIKROTIK_USER`: SSH username for the router
   - `MIKROTIK_BACKUP_ENCRYPT`: Password for encrypting the backup
   - `MIKROTIK_MAX_BACKUPS`: Maximum number of backup files to keep
   - `TZDATA`: Your timezone
   - `CRON_SCHEDULE`: Backup schedule in cron format

5. Start the container:
   ```
   docker-compose up -d
   ```

## ⚙️ Configuration

### 🔧 Environment Variables

- `MIKROTIK_ROUTER`: IP address of the MikroTik router
- `MIKROTIK_USER`: SSH username for the router
- `MIKROTIK_BACKUP_ENCRYPT`: Password for encrypting the backup
- `MIKROTIK_SSH_PORT`: SSH port of the router (default: 22)
- `MIKROTIK_MAX_BACKUPS`: Maximum number of backup files to keep
- `TZ`: Timezone for the container
- `CRON_SCHEDULE`: Cron schedule for running backups

### 💾 Volumes

- `./backups:/home/backupuser/backups`: Directory to store backup files
- `./id_rsa:/home/backupuser/.ssh/id_rsa:ro`: SSH private key for authentication
- `./known_hosts:/home/backupuser/.ssh/known_hosts:rw`: Known hosts file

## 📊 Logging

Logs are available in the container at:
- 📄 `/var/log/mikrotik_backup.log`: Backup operation logs
- 📄 `/var/log/cron.log`: Cron job logs

You can view these logs using Docker commands:
```
docker logs mikrotik-backup
```

## 🔍 Troubleshooting

1. Ensure your SSH key has the correct permissions:
   ```
   chmod 600 id_rsa
   ```

2. If backups are not running, check the cron logs and ensure the cron schedule is correct.

3. Verify that the MikroTik router is accessible from the Docker container.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📜 License

This project is open-source and available under the [MIT License](LICENSE).