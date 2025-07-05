#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

print_error() {
    echo -e "${RED}[-] $1${NC}"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

print_status "Installing Mac Plex Server Setup..."
print_status "Project directory: $PROJECT_DIR"

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_success "Homebrew already installed"
fi

# Install required packages
print_status "Installing required packages..."
if ! brew install --cask plex-media-server docker-desktop; then
    print_error "Failed to install Plex Media Server or Docker Desktop"
    exit 1
fi

if ! brew install traefik; then
    print_error "Failed to install Traefik"
    exit 1
fi

print_success "All packages installed successfully"

# Create necessary directories
print_status "Creating directory structure..."
mkdir -p "$PROJECT_DIR/traefik/certificates"
mkdir -p "$PROJECT_DIR/docker"

# Create acme.json with proper permissions (backup existing if present)
if [ -f "$PROJECT_DIR/traefik/certificates/acme.json" ] && [ -s "$PROJECT_DIR/traefik/certificates/acme.json" ]; then
    print_status "Backing up existing acme.json to acme.json.backup"
    cp "$PROJECT_DIR/traefik/certificates/acme.json" "$PROJECT_DIR/traefik/certificates/acme.json.backup"
    print_success "Existing certificates backed up"
else
    touch "$PROJECT_DIR/traefik/certificates/acme.json"
    chmod 600 "$PROJECT_DIR/traefik/certificates/acme.json"
    print_success "Created new acme.json file"
fi

# Verify environment file template exists
if [ ! -f "$PROJECT_DIR/docker/.env.example" ]; then
    print_error "Environment template file not found: $PROJECT_DIR/docker/.env.example"
    exit 1
fi
print_success "Environment template file found"

# Create LaunchAgent plist from template
print_status "Creating Traefik LaunchAgent..."
if [ -f "$PROJECT_DIR/traefik/LaunchAgents/com.traefik.startup.plist.template" ]; then
    # Backup existing LaunchAgent if it exists
    if [ -f "$HOME/Library/LaunchAgents/com.traefik.startup.plist" ]; then
        print_status "Backing up existing LaunchAgent to com.traefik.startup.plist.backup"
        cp "$HOME/Library/LaunchAgents/com.traefik.startup.plist" "$HOME/Library/LaunchAgents/com.traefik.startup.plist.backup"
        print_success "Existing LaunchAgent backed up"
    fi
    
    # Process the plist template
    sed "s|\${PROJECT_DIR}|$PROJECT_DIR|g" "$PROJECT_DIR/traefik/LaunchAgents/com.traefik.startup.plist.template" > "$HOME/Library/LaunchAgents/com.traefik.startup.plist"
    print_success "LaunchAgent created from template"
else
    print_error "LaunchAgent template not found"
    exit 1
fi

# Make scripts executable
chmod +x "$PROJECT_DIR/scripts/apply-config.sh"
chmod +x "$PROJECT_DIR/scripts/backup.sh"

# Setup Docker cleanup cron jobs
print_status "Setting up Docker cleanup cron jobs..."

# Check if cron jobs already exist to avoid duplicates
existing_cron=$(crontab -l 2>/dev/null | grep "docker system prune\|docker volume prune")

if [ -z "$existing_cron" ]; then
    # Get current crontab and add new jobs
    (crontab -l 2>/dev/null; echo "# Docker cleanup jobs - added by Mac Plex installer") | crontab -
    (crontab -l 2>/dev/null; echo "# Run every day at 3:00 AM - Docker system prune") | crontab -
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/docker system prune -af > /tmp/docker-prune.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "# Run every day at 3:05 AM - Docker volume prune") | crontab -
    (crontab -l 2>/dev/null; echo "5 3 * * * /usr/local/bin/docker volume prune -f >> /tmp/docker-prune.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "") | crontab -  # Add blank line for readability
    
    print_success "Docker cleanup cron jobs added successfully"
    print_status "Scheduled: Daily at 3:00 AM (system prune) and 3:05 AM (volume prune)"
else
    print_success "Docker cleanup cron jobs already exist, skipping"
fi

print_success "Installation complete!"
print_status "Next steps:"
print_status "1. Copy $PROJECT_DIR/docker/.env.example to $PROJECT_DIR/docker/.env (if not already done)"
print_status "2. Edit $PROJECT_DIR/docker/.env with your domain and email (if not already done)"
print_status "3. If Traefik is running, restart it: launchctl unload ~/Library/LaunchAgents/com.traefik.startup.plist && launchctl load ~/Library/LaunchAgents/com.traefik.startup.plist"
print_status "4. Start Docker containers: cd $PROJECT_DIR/docker && docker-compose up -d"
print_status ""
print_status "Automated cleanup:"
print_status "• Docker system cleanup: Daily at 3:00 AM"
print_status "• Docker volume cleanup: Daily at 3:05 AM"
print_status "• Cleanup logs: /tmp/docker-prune.log" 
