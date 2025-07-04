#!/bin/bash

# Configuration
BACKUP_DIR="/Volumes/Backup/plex"
DATE=$(date +%Y%m%d)
LOG_FILE="/tmp/plex_backup.log"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Backup Plex configuration
backup_plex() {
    log_message "Starting Plex configuration backup..."
    tar -czf "$BACKUP_DIR/plex_config_$DATE.tar.gz" ~/Library/Application\ Support/Plex\ Media\ Server/
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Plex configuration backup completed${NC}"
    else
        log_message "${RED}Plex configuration backup failed${NC}"
    fi
}

# Backup Docker volumes
backup_docker() {
    log_message "Starting Docker volumes backup..."
    cd ~/Documents/mac_plex/docker
    docker-compose down
    tar -czf "$BACKUP_DIR/docker_volumes_$DATE.tar.gz" ${DATA_DIR}
    docker-compose up -d
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Docker volumes backup completed${NC}"
    else
        log_message "${RED}Docker volumes backup failed${NC}"
    fi
}

# Backup Traefik configuration
backup_traefik() {
    log_message "Starting Traefik configuration backup..."
    sudo tar -czf "$BACKUP_DIR/traefik_config_$DATE.tar.gz" /private/etc/traefik/
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Traefik configuration backup completed${NC}"
    else
        log_message "${RED}Traefik configuration backup failed${NC}"
    fi
}

# Run backups
backup_plex
backup_docker
backup_traefik

# Clean up old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

log_message "Backup process completed" 