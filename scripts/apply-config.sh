#!/bin/bash

# Simple script to apply domain and email to configuration templates
# Usage: ./apply-config.sh yourdomain.com your@email.com [ip_allow_list]

if [ $# -lt 2 ]; then
    echo "Usage: $0 <domain> <email> [ip_allow_list]"
    echo "Example: $0 example.com your@email.com '127.0.0.1/32,10.0.0.0/24'"
    exit 1
fi

DOMAIN="$1"
EMAIL="$2"
# Third parameter overrides environment variable
if [ -n "$3" ]; then
    IP_ALLOW_LIST="$3"
fi

SCRIPT_DIR="$(dirname "$0")"

# Function to convert comma-separated IP list to YAML array
convert_ip_list_to_yaml() {
    local ip_list="$1"
    
    # Split the comma-separated list and convert to YAML array format
    IFS=',' read -ra IPS <<< "$ip_list"
    for ip in "${IPS[@]}"; do
        # Trim whitespace
        ip=$(echo "$ip" | xargs)
        echo "          - \"$ip\""
    done
}

# Dynamic configuration
DYNAMIC_TEMPLATE="$SCRIPT_DIR/../traefik/dynamic.yml.template"
DYNAMIC_OUTPUT="$SCRIPT_DIR/../traefik/dynamic.yml"

# Traefik configuration
TRAEFIK_TEMPLATE="$SCRIPT_DIR/../traefik/traefik.yml.template"
TRAEFIK_OUTPUT="$SCRIPT_DIR/../traefik/traefik.yml"

# Process dynamic.yml template
if [ -f "$DYNAMIC_TEMPLATE" ]; then
    # Convert IP_ALLOW_LIST to YAML format
    if [ -n "$IP_ALLOW_LIST" ]; then
        IP_YAML_LINES=$(convert_ip_list_to_yaml "$IP_ALLOW_LIST")
    else
        # Default fallback IPs
        IP_YAML_LINES='          - "127.0.0.1/32"
          - "192.168.1.0/24"'
    fi
    
    # Process the template using a temporary file approach
    # First replace domain with sed
    sed "s/\${DOMAIN}/$DOMAIN/g" "$DYNAMIC_TEMPLATE" > "$DYNAMIC_OUTPUT.tmp"
    
    # Create a temporary file with the IP YAML lines
    TEMP_IP_FILE=$(mktemp)
    echo "$IP_YAML_LINES" > "$TEMP_IP_FILE"
    
    # Now replace IP_ALLOW_LIST placeholder with the contents of the temp file
    # Use perl for reliable multiline replacement
    perl -pe '
        if (/\$\{IP_ALLOW_LIST\}/) {
            open(my $fh, "<", "'$TEMP_IP_FILE'") or die "Cannot open temp file: $!";
            my $replacement = do { local $/; <$fh> };
            close($fh);
            chomp($replacement);
            s/\$\{IP_ALLOW_LIST\}/$replacement/g;
        }
    ' "$DYNAMIC_OUTPUT.tmp" > "$DYNAMIC_OUTPUT"
    
    # Clean up temp files
    rm "$TEMP_IP_FILE" "$DYNAMIC_OUTPUT.tmp"
    
    echo "✅ Applied domain '$DOMAIN' and IP allowlist to dynamic.yml"
else
    echo "⚠️  Dynamic template not found: $DYNAMIC_TEMPLATE"
fi

# Process traefik.yml template
if [ -f "$TRAEFIK_TEMPLATE" ]; then
    sed "s/\${LETSENCRYPT_EMAIL}/$EMAIL/g" "$TRAEFIK_TEMPLATE" > "$TRAEFIK_OUTPUT"
    echo "✅ Applied email '$EMAIL' to traefik.yml"
else
    echo "⚠️  Traefik template not found: $TRAEFIK_TEMPLATE"
fi 