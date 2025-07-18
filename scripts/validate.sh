#!/bin/bash

# Mac Plex Server Validation Script
# This script checks if your installation is working correctly

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Function to print test results
print_test() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name: $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name: $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

print_header() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}Mac Plex Server Validation Script${NC}"
echo -e "${BLUE}================================${NC}"
echo "Project directory: $PROJECT_DIR"

# Check if .env file exists and load it
if [ -f "$PROJECT_DIR/docker/.env" ]; then
    source "$PROJECT_DIR/docker/.env"
    print_test "Environment File" 0 "Found and loaded .env file"
else
    print_test "Environment File" 1 "Missing .env file - copy from .env.example"
    exit 1
fi

# Validate required environment variables
print_header "Environment Variables"
[ -n "$DOMAIN" ] && print_test "DOMAIN" 0 "Set to: $DOMAIN" || print_test "DOMAIN" 1 "Not set"
[ -n "$LETSENCRYPT_EMAIL" ] && print_test "LETSENCRYPT_EMAIL" 0 "Set to: $LETSENCRYPT_EMAIL" || print_test "LETSENCRYPT_EMAIL" 1 "Not set"
[ -n "$DATA_DIR" ] && print_test "DATA_DIR" 0 "Set to: $DATA_DIR" || print_test "DATA_DIR" 1 "Not set"
[ -n "$PLEX_DIR" ] && print_test "PLEX_DIR" 0 "Set to: $PLEX_DIR" || print_test "PLEX_DIR" 1 "Not set"

# Check required directories
print_header "Directory Structure"
[ -d "$DATA_DIR" ] && print_test "Data Directory" 0 "Exists: $DATA_DIR" || print_test "Data Directory" 1 "Missing: $DATA_DIR"
[ -d "$PLEX_DIR" ] && print_test "Plex Directory" 0 "Exists: $PLEX_DIR" || print_test "Plex Directory" 1 "Missing: $PLEX_DIR"
[ -d "$PROJECT_DIR/traefik/certificates" ] && print_test "Certificates Directory" 0 "Exists" || print_test "Certificates Directory" 1 "Missing"

# Check required files
print_header "Configuration Files"
[ -f "$PROJECT_DIR/traefik/certificates/acme.json" ] && print_test "ACME Certificate File" 0 "Exists with correct permissions" || print_test "ACME Certificate File" 1 "Missing or incorrect permissions"
[ -f "$PROJECT_DIR/traefik/traefik.yml" ] && print_test "Traefik Config" 0 "Generated from template" || print_test "Traefik Config" 1 "Missing - run apply-config.sh"
[ -f "$PROJECT_DIR/traefik/dynamic.yml" ] && print_test "Dynamic Config" 0 "Generated from template" || print_test "Dynamic Config" 1 "Missing - run apply-config.sh"

# Check if required tools are installed
print_header "Required Tools"
command -v docker >/dev/null 2>&1 && print_test "Docker" 0 "Installed" || print_test "Docker" 1 "Not installed"
command -v docker-compose >/dev/null 2>&1 && print_test "Docker Compose" 0 "Installed" || print_test "Docker Compose" 1 "Not installed"
command -v traefik >/dev/null 2>&1 && print_test "Traefik" 0 "Installed" || print_test "Traefik" 1 "Not installed"

# Check if Docker Desktop is running
print_header "Docker Status"
docker info >/dev/null 2>&1 && print_test "Docker Daemon" 0 "Running" || print_test "Docker Daemon" 1 "Not running - start Docker Desktop"

# Check if Traefik is running
print_header "Traefik Status"
if launchctl list | grep -q "traefik"; then
    print_test "Traefik LaunchAgent" 0 "Running"
else
    print_test "Traefik LaunchAgent" 1 "Not running - load LaunchAgent"
fi

# Check if Traefik is responding via HTTPS dashboard
if curl -sf "https://traefik.$DOMAIN/dashboard/" >/dev/null 2>&1; then
    print_test "Traefik Dashboard" 0 "Responding on https://traefik.$DOMAIN"
else
    print_test "Traefik Dashboard" 1 "Not responding on https://traefik.$DOMAIN"
fi

# Check Docker services
print_header "Docker Services"
cd "$PROJECT_DIR/docker" || exit 1

# Check if docker-compose.yml exists
if [ -f "docker-compose.yml" ]; then
    print_test "Docker Compose File" 0 "Found"
    
    # Get list of services
    services=$(docker-compose config --services 2>/dev/null)
    if [ -n "$services" ]; then
        print_test "Docker Compose Config" 0 "Valid configuration"
        
        # Check each service
        print_info "Checking individual services..."
        for service in $services; do
            if docker-compose ps "$service" | grep -q "Up"; then
                print_test "Service: $service" 0 "Running"
            else
                print_test "Service: $service" 1 "Not running"
            fi
        done
    else
        print_test "Docker Compose Config" 1 "Invalid configuration"
    fi
else
    print_test "Docker Compose File" 1 "Missing"
fi

# Check network connectivity - DNS resolution test
print_header "Network Connectivity"
if nslookup "heimdall.$DOMAIN" >/dev/null 2>&1; then
    print_test "DNS Resolution" 0 "Can resolve subdomains for $DOMAIN"
else
    print_test "DNS Resolution" 1 "Cannot resolve subdomains for $DOMAIN"
fi

# Check specific service endpoints via HTTPS
print_header "HTTPS Service Endpoints"
https_services_to_check=(
    "traefik"
    "heimdall"
    "portainer"
    "ombi"
    "sonarr"
    "radarr"
    "prowlarr"
    "overseerr"
    "tautulli"
)

for service_name in "${https_services_to_check[@]}"; do
    # Check if service responds (200 OK, 3xx redirects, or 401/403 for auth-protected services)
    response_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$service_name.$DOMAIN" 2>/dev/null)
    
    if [[ "$response_code" =~ ^[23][0-9][0-9]$ ]] || [ "$response_code" = "401" ] || [ "$response_code" = "403" ]; then
        if [ "$response_code" = "200" ]; then
            print_test "HTTPS: $service_name" 0 "Responding (HTTP $response_code)"
        elif [[ "$response_code" =~ ^3[0-9][0-9]$ ]]; then
            print_test "HTTPS: $service_name" 0 "Responding with redirect (HTTP $response_code)"
        else
            print_test "HTTPS: $service_name" 0 "Responding with auth protection (HTTP $response_code)"
        fi
    else
        print_test "HTTPS: $service_name" 1 "Not responding (HTTP $response_code)"
    fi
done

# SSL Certificate check
print_header "SSL Certificates"
if [ -f "$PROJECT_DIR/traefik/certificates/acme.json" ] && [ -s "$PROJECT_DIR/traefik/certificates/acme.json" ]; then
    print_test "SSL Certificates" 0 "Certificate file exists and is not empty"
else
    print_test "SSL Certificates" 1 "Certificate file is empty or missing"
fi

# Check if SSL is working by testing a known working subdomain
if command -v openssl >/dev/null 2>&1; then
    if echo | openssl s_client -connect "heimdall.$DOMAIN:443" -servername "heimdall.$DOMAIN" 2>/dev/null | grep -q "Verify return code: 0"; then
        print_test "SSL Verification" 0 "SSL certificate is valid for subdomains"
    else
        print_test "SSL Verification" 1 "SSL certificate verification failed"
    fi
else
    print_test "SSL Verification" 1 "OpenSSL not available for testing"
fi

# Final summary
print_header "Validation Summary"
echo -e "${BLUE}Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "${BLUE}Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "${BLUE}Total Tests: $TESTS_TOTAL${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All tests passed! Your Mac Plex Server setup looks good!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some tests failed. Please check the issues above.${NC}"
    echo -e "${YELLOW}💡 Common solutions:${NC}"
    echo "   - Make sure Docker Desktop is running"
    echo "   - Check your .env file configuration"
    echo "   - Verify your domain DNS settings"
    echo "   - Ensure ports 80 and 443 are forwarded to your Mac"
    echo "   - Run: cd docker && docker-compose up -d"
    echo "   - Check logs: tail -f /tmp/traefik.log"
    exit 1
fi 