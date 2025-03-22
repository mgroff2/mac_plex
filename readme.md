# Mac Plex Media Server Setup

This repository contains the configuration and setup scripts for running a Plex Media Server on macOS with Docker containers for supporting services and Traefik as a reverse proxy.

## Prerequisites

- macOS (tested on Apple Silicon)
- Administrative access
- Command line tools (`xcode-select --install`)

## Quick Start

1. Clone this repository:
```bash
git clone https://github.com/yourusername/mac_plex.git
cd mac_plex
```

2. Run the installation script:
```bash
chmod +x install.sh
./install.sh
```

## Manual Installation

If you prefer to install components manually, follow these steps:

### 1. Install Required Software

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Docker Desktop
brew install --cask docker
brew install docker-clean docker-completion docker-compose

# Install Plex Media Server
brew install --cask plex-media-server

# Install Traefik
brew install traefik
```

### 2. Configure Traefik

Traefik configuration files are stored in `/private/etc/traefik/`:
- `traefik.yml`: Main configuration
- `dynamic.yml`: Dynamic routing configuration
- `certificates/acme.json`: SSL certificates

### 3. Configure Docker

Docker configuration files are stored in `~/Documents/mac_plex/docker/`:
- `docker-compose.yml`: Service definitions
- `.env`: Environment variables

## Directory Structure

```
mac_plex/
├── docker/
│   ├── .env
│   └── docker-compose.yml
├── traefik/
│   ├── certificates/
│   ├── traefik.yml
│   └── dynamic.yml
├── scripts/
│   └── backup.sh
├── install.sh
└── readme.md
```

## Post-Installation

1. Configure Plex Media Server:
   - Open Plex Web App at http://localhost:32400/web
   - Follow the setup wizard

2. Configure your media directories in Plex:
   - Movies: `/path/to/your/plex/mediaMovies`
   - TV Shows: `/path/to/your/plex/mediaTV Shows`
   - Music: `/path/to/your/plex/mediaMusic`

3. Verify Traefik is running:
   - Check dashboard at https://traefik.yourdomain.com
   - Verify SSL certificates are working

## Maintenance

- Backup script: `scripts/backup.sh`
- Logs: Check Docker Desktop or `/tmp/traefik.log`
- Updates: Run `brew update && brew upgrade`

## Troubleshooting

Common issues and solutions:

1. Traefik not starting:
```bash
launchctl unload ~/Library/LaunchAgents/com.traefik.startup.plist
launchctl load ~/Library/LaunchAgents/com.traefik.startup.plist
```

2. Docker containers not accessible:
- Check Docker Desktop is running
- Verify network settings
- Check Traefik logs

## Contributing

Feel free to submit issues and pull requests.

## License

MIT 