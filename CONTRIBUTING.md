# Contributing to Mac Plex Server

Thank you for your interest in contributing to the Mac Plex Server project! This guide will help you get started.

## How to Contribute

### 🐛 Reporting Bugs
- Use the GitHub issue tracker
- Search existing issues before creating new ones
- Include detailed information:
  - macOS version
  - Docker version
  - Complete error messages
  - Steps to reproduce
  - Your `.env` configuration (remove sensitive data)

### 💡 Suggesting Features
- Create a GitHub issue with the "enhancement" label
- Describe the feature and its benefits
- Explain how it fits with the project's goals

### 🔧 Code Contributions

#### Before You Start
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Test your changes thoroughly

#### Development Guidelines
- **Docker Services**: Follow the existing pattern in `docker-compose.yml`
- **Scripts**: Use proper error handling and logging
- **Documentation**: Update README.md for any new features
- **Templates**: Use the template system for configuration files

#### Testing Your Changes
1. Test the installation script on a clean macOS system
2. Verify all services start correctly
3. Check SSL certificate generation
4. Test backup/restore functionality

#### Submitting Changes
1. Ensure your code follows the existing style
2. Update documentation as needed
3. Test on a clean system if possible
4. Submit a pull request with a clear description

### 📚 Documentation
- Fix typos or improve clarity in README.md
- Add troubleshooting solutions you've discovered
- Improve installation instructions
- Add examples for common configurations

### 🏗️ Architecture Changes
For major changes (new services, architecture modifications):
1. Open an issue first to discuss the change
2. Wait for maintainer feedback before implementing
3. Update architecture diagrams if needed
4. Ensure backward compatibility where possible

## Development Setup

### Prerequisites
- macOS 14+ (recommended)
- Docker Desktop
- Git

### Local Development
```bash
# Clone your fork
git clone https://github.com/yourusername/mac_plex.git
cd mac_plex

# Create a test environment
cp docker/.env.example docker/.env.test
# Edit .env.test with test values

# Test your changes
./scripts/install.sh
```

## Code Style

### Shell Scripts
- Use `#!/bin/bash` shebang
- Include error handling with `set -e` when appropriate
- Use meaningful variable names
- Add comments for complex logic
- Include status messages for user feedback

### Docker Compose
- Use consistent indentation (2 spaces)
- Include restart policies
- Add health checks where applicable
- Use environment variables from `.env`
- Include Watchtower labels for auto-updates

### Documentation
- Use clear, concise language
- Include code examples
- Add troubleshooting steps for common issues
- Keep the table of contents updated

## Service Addition Guidelines

When adding new services:

1. **Choose appropriate images**: Prefer official or well-maintained images
2. **Follow naming conventions**: Use lowercase, hyphenated names
3. **Add to all necessary files**:
   - `docker-compose.yml` - Service definition
   - `traefik/dynamic.yml.template` - Routing configuration
   - `README.md` - Documentation
4. **Include proper configuration**:
   - Environment variables
   - Volume mounts
   - Network configuration
   - Health checks
5. **Test thoroughly**: Ensure the service integrates well with existing stack

## Questions?

- Open an issue for questions about contributing
- Check existing issues and pull requests
- Read the README.md troubleshooting section

## Recognition

Contributors will be acknowledged in the README.md file and GitHub contributors list.

Thank you for helping make this project better! 🎉 