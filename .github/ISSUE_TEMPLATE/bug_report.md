---
name: Bug Report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description
A clear and concise description of what the bug is.

## Environment
- **macOS Version**: [e.g., macOS 14.5]
- **Docker Version**: [e.g., Docker Desktop 4.24.0]
- **Traefik Version**: [e.g., v3.0]
- **Architecture**: [e.g., Intel/Apple Silicon]

## Steps to Reproduce
1. Go to '...'
2. Click on '...'
3. Scroll down to '...'
4. See error

## Expected Behavior
A clear and concise description of what you expected to happen.

## Actual Behavior
A clear and concise description of what actually happened.

## Error Messages
```
Paste any error messages here (from logs, terminal, etc.)
```

## Configuration
Please provide relevant parts of your configuration (remove sensitive data):

**Environment Variables** (remove passwords/tokens):
```bash
DOMAIN=example.com
PUID=1000
PGID=1000
# etc.
```

**Docker Logs** (if applicable):
```
docker logs [container-name]
```

**Traefik Logs** (if applicable):
```
tail -f /tmp/traefik.log
```

## Screenshots
If applicable, add screenshots to help explain your problem.

## Additional Context
Add any other context about the problem here.

## Checklist
- [ ] I have searched existing issues
- [ ] I have read the troubleshooting section in README.md
- [ ] I have included all requested information
- [ ] I have removed sensitive data from logs/config 