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

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    print_success "Homebrew already installed"
fi

# Install required packages
print_status "Installing required packages..."
brew install --cask docker plex-media-server
brew install traefik docker-clean docker-completion docker-compose

# Create necessary directories
print_status "Creating directory structure..."
sudo mkdir -p /private/etc/traefik/certificates
mkdir -p ~/Documents/mac_plex/{docker,traefik,scripts}

# Copy configuration files
print_status "Copying configuration files..."
sudo cp ./traefik/traefik.yml /private/etc/traefik/
sudo cp ./traefik/dynamic.yml /private/etc/traefik/
sudo touch /private/etc/traefik/certificates/acme.json
sudo chmod 600 /private/etc/traefik/certificates/acme.json

# Setup Traefik LaunchAgent
print_status "Setting up Traefik LaunchAgent..."
cp ./traefik/com.traefik.startup.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.traefik.startup.plist

# Copy Docker configuration
print_status "Setting up Docker configuration..."
cp ./docker/.env ~/Documents/mac_plex/docker/
cp ./docker/docker-compose.yml ~/Documents/mac_plex/docker/

# Start services
print_status "Starting services..."
open -a Docker
open -a Plex\ Media\ Server

print_success "Installation complete!"
print_status "Please check the readme.md file for post-installation steps." 