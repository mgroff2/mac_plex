# Security Guide for Mac Plex Server

This guide outlines security considerations and best practices for your Mac Plex Server setup.

## 🔐 Security Overview

The Mac Plex Server setup includes several security measures by default:

- **SSL/TLS Encryption**: All external traffic is encrypted using Let's Encrypt certificates
- **IP Whitelisting**: Access is restricted to specified IP ranges
- **Network Isolation**: Services run in isolated Docker networks
- **Automatic Updates**: Watchtower keeps containers updated with security patches

## 🛡️ Built-in Security Features

### 1. **SSL Certificate Management**
- **Automatic SSL**: Let's Encrypt certificates are automatically generated and renewed
- **Certificate Storage**: Certificates are stored in `traefik/certificates/acme.json` with restricted permissions (600)
- **HTTPS Redirect**: All HTTP traffic is automatically redirected to HTTPS
- **SSL Verification**: Certificates are validated and trusted by browsers

### 2. **Network Security**
- **IP Whitelisting**: Only specified IP ranges can access your services
- **Firewall Integration**: Works with macOS firewall and router port forwarding
- **Private Networks**: Docker containers communicate over private networks
- **Port Isolation**: Services are only accessible through Traefik reverse proxy

### 3. **Access Control**
- **Service-level Protection**: Each service has its own authentication
- **Admin-only Services**: Critical services (Portainer, Grafana) require additional authentication
- **Request Approval**: Media requests require admin approval via Ombi/Overseerr

## 🔒 Security Configuration

### IP Whitelisting Setup
Configure your allowed IP ranges in the `.env` file:

```bash
# Allow local network and specific remote IPs
IP_ALLOW_LIST=127.0.0.1/32,192.168.1.0/24,10.0.0.0/8,YOUR.REMOTE.IP/32
```

**IP Range Examples:**
- `127.0.0.1/32` - Localhost only
- `192.168.1.0/24` - Local network (192.168.1.1-254)
- `10.0.0.0/8` - Larger private network
- `76.123.45.67/32` - Specific public IP address

### Router Security
**Port Forwarding Rules:**
- Forward ports 80 and 443 to your Mac's IP
- **DO NOT** forward other ports (3306, 8080, etc.)
- Consider using non-standard external ports if your ISP allows

### macOS Security
```bash
# Enable macOS firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Allow Traefik through firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/traefik
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/local/bin/traefik
```

## 🔐 Authentication & Passwords

### 1. **Service Authentication**
Each service has its own authentication system:

- **Plex**: Plex account authentication
- **Ombi**: User registration with admin approval
- **Sonarr/Radarr**: API key authentication
- **Portainer**: Admin password setup
- **MySQL**: Database credentials

### 2. **Password Management**
**Strong Password Requirements:**
- Use unique passwords for each service
- Minimum 12 characters with mixed case, numbers, symbols
- Store passwords in a password manager
- Regular password rotation (every 6 months)

**Generate Strong Passwords:**
```bash
# Generate a random password
openssl rand -base64 32

# Or use built-in macOS password generator
security add-generic-password -a "service" -s "mac-plex" -w $(openssl rand -base64 24)
```

### 3. **Database Security**
Update MySQL passwords regularly:

```bash
# Connect to MySQL
docker exec -it mysql mysql -u root -p

# Change root password
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_secure_password';

# Create service-specific users
CREATE USER 'ombi'@'%' IDENTIFIED BY 'ombi_password';
GRANT ALL PRIVILEGES ON ombi_db.* TO 'ombi'@'%';
```

## 🔍 Monitoring & Logging

### 1. **Security Monitoring**
- **Uptime Kuma**: Monitors service availability
- **Traefik Logs**: Access logs for security analysis
- **Docker Logs**: Container security events
- **macOS Logs**: System-level security events

### 2. **Log Analysis**
**Check for suspicious activity:**
```bash
# Review Traefik access logs
tail -f /tmp/traefik.log | grep -E "(403|404|500)"

# Check for failed authentication attempts
docker logs ombi | grep -i "failed\|error\|unauthorized"

# Monitor MySQL connections
docker logs mysql | grep -i "access denied\|connection from"
```

### 3. **Automated Alerts**
Configure Discord/email alerts for:
- Failed login attempts
- Service outages
- SSL certificate expiration
- Unusual traffic patterns

## 🛠️ Security Maintenance

### 1. **Regular Updates**
- **Watchtower**: Automatically updates containers
- **Traefik**: Update manually when new versions are available
- **macOS**: Keep system updated with security patches
- **Docker**: Update Docker Desktop regularly

### 2. **Security Audits**
**Monthly Security Checklist:**
- [ ] Review IP whitelist for accuracy
- [ ] Check SSL certificate status
- [ ] Audit user accounts in each service
- [ ] Review access logs for anomalies
- [ ] Verify backup integrity
- [ ] Update passwords where needed

### 3. **Backup Security**
- **Encryption**: Encrypt backups containing sensitive data
- **Storage**: Store backups in secure, separate location
- **Access**: Restrict backup access to authorized personnel
- **Testing**: Regularly test backup restoration

## 🚨 Incident Response

### 1. **Security Breach Response**
If you suspect a security breach:

1. **Immediate Actions:**
   ```bash
   # Stop all services
   cd docker && docker-compose down
   
   # Stop Traefik
   launchctl unload ~/Library/LaunchAgents/com.traefik.startup.plist
   
   # Check system logs
   log show --predicate 'eventMessage contains "security"' --last 24h
   ```

2. **Investigation:**
   - Review access logs for unauthorized access
   - Check for new user accounts
   - Verify configuration files haven't been modified
   - Check for unauthorized file changes

3. **Recovery:**
   - Change all passwords immediately
   - Update IP whitelist to remove suspicious IPs
   - Restore from clean backups if needed
   - Update all services to latest versions

### 2. **Emergency Contacts**
- Have contact information for your ISP ready
- Know how to quickly disable port forwarding
- Have offline backups available

## 📚 Additional Security Resources

### Recommended Reading
- [OWASP Security Guidelines](https://owasp.org)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Traefik Security Documentation](https://doc.traefik.io/traefik/https/tls/)
- [macOS Security Guide](https://support.apple.com/guide/security/)

### Security Tools
- **Fail2ban**: Intrusion prevention system
- **ClamAV**: Antivirus scanning
- **Nmap**: Network security scanning
- **Wireshark**: Network traffic analysis

## 🎯 Security Best Practices Summary

1. **Keep Everything Updated**: Enable automatic updates where possible
2. **Use Strong Authentication**: Unique passwords, 2FA where available
3. **Monitor Regularly**: Check logs and alerts daily
4. **Backup Securely**: Encrypted, tested, offsite backups
5. **Limit Access**: Principle of least privilege for all services
6. **Regular Audits**: Monthly security reviews
7. **Stay Informed**: Subscribe to security advisories for your services

## 🔗 Report Security Issues

If you discover a security vulnerability in this setup:

1. **DO NOT** open a public GitHub issue
2. Email security concerns to the maintainers
3. Include detailed information about the vulnerability
4. Allow reasonable time for response and patching

Remember: Security is an ongoing process, not a one-time setup. Regular maintenance and vigilance are key to keeping your Mac Plex Server secure. 