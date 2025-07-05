# Changelog

All notable changes to the Mac Plex Server project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-07

### 🎉 Initial Release

Complete Mac Plex Server setup with automated installation, configuration, and management tools.

### ✨ Added

#### 🐳 **Docker Infrastructure**
- **Complete Docker Compose stack** with 20+ integrated services
- **Traefik reverse proxy** with automatic HTTPS/SSL certificate management
- **Network isolation** with dedicated `traefik-proxy` network
- **Health checks** for critical services (MySQL, Portainer, Heimdall)

#### 📺 **Plex Media Services**
- **Radarr** - Movie collection management
- **Sonarr** - TV series collection management  
- **Lidarr** - Music collection management
- **Bazarr** - Subtitle management
- **Prowlarr** - Indexer management
- **NZBGet** - Usenet downloader
- **Ombi** - Media request management
- **Overseerr** - Alternative request management
- **Tautulli** - Plex analytics and monitoring

#### 🤖 **AI Integration**
- **Ollama** - Local LLM server
- **Open WebUI** - Chat interface for AI models

#### 📊 **Dashboard & Management**
- **Heimdall** - Application dashboard
- **Organizr** - Service organization
- **Portainer** - Docker container management
- **Portainer Agent** - Multi-node support

#### 🗄️ **Database Services**
- **MySQL 8.4.0** - Primary database with optimized configuration
- **phpMyAdmin** - Database web interface
- **Adminer** - Lightweight database management

#### 🔧 **Utilities & Monitoring**
- **Watchtower** - Automatic container updates
- **Uptime Kuma** - Service monitoring
- **IT-Tools** - Various utility tools
- **Grafana** - Metrics visualization
- **Prometheus** - Metrics collection

#### 🚀 **Installation & Setup**
- **Automated installer** (`install.sh`) with:
  - Homebrew package management
  - Docker Desktop installation
  - Plex Media Server installation
  - Traefik binary installation
  - Directory structure creation
  - LaunchAgent configuration
  - **Docker cleanup cron jobs** (daily at 3:00 AM & 3:05 AM)
- **Environment configuration** with template system
- **SSL certificate management** with automatic Let's Encrypt integration

#### 🔍 **Validation & Health Checks**
- **Comprehensive validation script** (`validate.sh`) with:
  - Environment variable verification
  - Directory structure validation
  - Configuration file checks
  - Tool installation verification
  - Docker service status monitoring
  - **HTTPS endpoint testing** with auth-aware checks
  - **DNS resolution testing**
  - **SSL certificate validation**

#### ⚙️ **Configuration Management**
- **Template-based configuration** (`apply-config.sh`) with:
  - Domain and email substitution
  - IP allowlist management (YAML format)
  - Dynamic Traefik configuration
- **Backup system** (`backup.sh`) for:
  - Plex configuration
  - Docker volumes
  - Traefik configuration

#### 🔒 **Security Features**
- **HTTPS-only access** via Traefik with automatic HTTP→HTTPS redirects
- **IP allowlist protection** for sensitive services
- **Password authentication** on critical services
- **SSL certificate automation** with Let's Encrypt
- **Secure file permissions** (acme.json with 600 permissions)

#### 🍎 **macOS Integration**
- **LaunchAgent configuration** for Traefik auto-startup
- **Homebrew integration** for package management
- **Case-insensitive filesystem support**
- **macOS-optimized MySQL configuration**

### 🔧 **Configuration**

#### Environment Variables
- `DOMAIN` - Your domain name
- `LETSENCRYPT_EMAIL` - Email for SSL certificates
- `DATA_DIR` - Docker data directory path
- `PLEX_DIR` - Plex media directory path
- `MYSQL_ROOT_PASSWORD` - Database root password
- `IP_ALLOW_LIST` - Comma-separated IP ranges for access control
- `PUID`/`PGID` - User/group IDs for file permissions
- `TZ` - Timezone configuration

#### Service Ports
- **Traefik Dashboard**: `https://traefik.yourdomain.com`
- **Heimdall**: `https://heimdall.yourdomain.com` (Port 8282)
- **Portainer**: `https://portainer.yourdomain.com` (Port 9000)
- **Ombi**: `https://ombi.yourdomain.com` (Port 3579)
- **Radarr**: `https://radarr.yourdomain.com` (Port 7878)
- **Sonarr**: `https://sonarr.yourdomain.com` (Port 8989)
- **MySQL**: Port 3306
- **And 15+ additional services** with HTTPS access

### 🛠️ **Technical Details**

#### Docker Compose Features
- **Multi-service orchestration** with 23 containers
- **Volume persistence** for all application data
- **Network isolation** with bridge networking
- **Automatic restart policies** (`unless-stopped`)
- **Resource optimization** with health checks
- **Watchtower integration** for automatic updates

#### Traefik Configuration
- **Automatic service discovery** via Docker labels
- **Let's Encrypt integration** with HTTP-01 challenge
- **HTTP to HTTPS redirection**
- **Dashboard with authentication**
- **IP allowlist middleware**
- **Dynamic configuration reload**

#### MySQL Optimization
- **InnoDB buffer pool**: 512M
- **Connection limits**: 200 max connections
- **Timeout configuration**: 300s wait/interactive timeout
- **Case-insensitive table names** for macOS compatibility
- **Optimized flush settings** for container environments

### 📚 **Documentation**

#### Scripts
- `scripts/install.sh` - Complete system installation
- `scripts/validate.sh` - System health validation  
- `scripts/apply-config.sh` - Configuration management
- `scripts/backup.sh` - Backup automation

#### Templates
- `docker/.env.example` - Environment configuration template
- `traefik/traefik.yml.template` - Traefik main configuration
- `traefik/dynamic.yml.template` - Dynamic routing configuration
- `traefik/LaunchAgents/com.traefik.startup.plist.template` - macOS service

#### Configuration Files
- `docker/docker-compose.yml` - Complete service stack
- `traefik/certificates/acme.json` - SSL certificate storage

### 🔄 **Automation**

#### Cron Jobs
- **Daily Docker cleanup** at 3:00 AM (`docker system prune -af`)
- **Daily volume cleanup** at 3:05 AM (`docker volume prune -f`)
- **Cleanup logging** to `/tmp/docker-prune.log`

#### Service Management
- **Automatic container updates** via Watchtower
- **Health monitoring** with restart policies
- **SSL certificate renewal** via Let's Encrypt
- **Traefik auto-startup** via macOS LaunchAgent

### 📋 **Requirements**

#### System Requirements
- **macOS** with case-insensitive filesystem support
- **Homebrew** package manager
- **Docker Desktop** for container orchestration
- **Internet connection** for SSL certificates and updates

#### Network Requirements
- **Domain name** with DNS configured
- **Ports 80/443** forwarded to Mac
- **Outbound HTTPS** for Let's Encrypt challenges

---

### 🚀 **Getting Started**

1. **Clone the repository**
2. **Run the installer**: `./scripts/install.sh`
3. **Configure environment**: Copy and edit `docker/.env.example` to `docker/.env`
4. **Apply configuration**: `./scripts/apply-config.sh yourdomain.com your@email.com`
5. **Start services**: `cd docker && docker-compose up -d`
6. **Validate setup**: `./scripts/validate.sh`

### 🎯 **What's Next**

This v1.0 release provides a complete, production-ready Mac Plex server setup with enterprise-grade features including automatic SSL, service discovery, monitoring, and maintenance automation.

---

*For more information, visit the [GitHub repository](https://github.com/yourusername/mac_plex)*

---

## Version History Notes

### Versioning Strategy
- **Major versions (X.0.0)**: Breaking changes, major new features
- **Minor versions (X.Y.0)**: New features, backwards compatible
- **Patch versions (X.Y.Z)**: Bug fixes, security updates

### Release Process
1. Update version numbers in relevant files
2. Update CHANGELOG.md with new changes
3. Create release notes
4. Tag release in Git
5. Update documentation if needed

### Upgrade Guidelines
- Always backup before upgrading
- Check compatibility notes for breaking changes
- Test in development environment first
- Follow migration guides for major versions

---

## Contributing to Changelog

When contributing, please:
1. Add your changes to the [Unreleased] section
2. Use the established format and categories
3. Include breaking changes prominently
4. Link to relevant issues or PRs
5. Update the version number when releasing

### Change Categories
- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for security-related changes 