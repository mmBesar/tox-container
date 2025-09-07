#!/bin/sh
set -e

# Tox Bootstrap Daemon Entrypoint Script
# Generates configuration from environment variables and manages the daemon

# Color output for logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Function to get local IP address
get_local_ip() {
    # Try to get the default route interface IP
    ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || \
    hostname -i 2>/dev/null | awk '{print $1}' || \
    echo "127.0.0.1"
}

# Function to get public IP address
get_public_ip() {
    # Try multiple services for redundancy
    curl -s --max-time 5 ipinfo.io/ip 2>/dev/null || \
    curl -s --max-time 5 ifconfig.me 2>/dev/null || \
    curl -s --max-time 5 icanhazip.com 2>/dev/null | tr -d '\n' || \
    echo ""
}

# Function to convert log level to number
get_log_level_num() {
    case "$TOX_LOG_LEVEL" in
        TRACE) echo "0" ;;
        DEBUG) echo "1" ;;
        INFO)  echo "2" ;;
        WARNING) echo "3" ;;
        ERROR) echo "4" ;;
        *) echo "2" ;;  # Default to INFO
    esac
}

# Function to generate bootstrap nodes configuration
generate_bootstrap_nodes() {
    if [ "$TOX_ENABLE_PUBLIC_BOOTSTRAP" != "true" ]; then
        echo ""
        return
    fi

    # Well-known public bootstrap nodes (curated list)
    cat << 'EOF'
    {
        address = "node.tox.biribiri.org"
        port = 33445
        public_key = "F404ABAA1C99A9D37D61AB54898F56793E1DEF8BD46B1038B9D822E8460FAB67"
    },
    {
        address = "tox.verdict.gg"
        port = 33445
        public_key = "1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976"
    },
    {
        address = "tox.initramfs.io"
        port = 33445
        public_key = "3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25"
    },
    {
        address = "bootstrap.tox.chat"
        port = 33445
        public_key = "6FC41E2BD381D37E9748FC0E0328CE086AF9598BECC8FEB7DDF2E440475F300E"
    },
    {
        address = "95.31.18.227"
        port = 33445
        public_key = "257744DBF57BE3E117FE05D145B5F806089428D4DCE4E3D0D50616AA16D417FF"
    },
    {
        address = "46.229.52.198"
        port = 33445
        public_key = "813C8F4187833EF0655B10F7752141A352248462A567529A38B6BBF73E979307"
    }
EOF
}

# Function to extract public key from keys file
get_public_key() {
    if [ -f "$TOX_KEYS_FILE" ]; then
        # The public key is the first 32 bytes (64 hex chars) of the keys file
        # Use dd to read exactly 32 bytes, then convert to hex
        dd if="$TOX_KEYS_FILE" bs=32 count=1 2>/dev/null | hexdump -v -e '32/1 "%02X" ""' 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to wait for keys file and extract public key
wait_for_keys() {
    local max_wait=30
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if [ -f "$TOX_KEYS_FILE" ] && [ -s "$TOX_KEYS_FILE" ]; then
            local key=$(get_public_key)
            if [ -n "$key" ] && [ ${#key} -eq 64 ]; then
                echo "$key"
                return 0
            fi
        fi
        sleep 1
        count=$((count + 1))
    done
    
    echo ""
    return 1
}

# Function to generate bootstrap info JSON
generate_bootstrap_info() {
    if [ "$TOX_GENERATE_BOOTSTRAP_INFO" != "true" ]; then
        return
    fi

    local_ip="${TOX_LOCAL_IP:-$(get_local_ip)}"
    public_ip="${TOX_PUBLIC_IP:-$(get_public_ip)}"
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    log "Waiting for public key to be available..."
    public_key=$(wait_for_keys)
    
    if [ -z "$public_key" ]; then
        warn "Could not extract public key for bootstrap info"
        public_key="UNKNOWN"
    fi
    
    log "Generating bootstrap info file..."
    
    # Start JSON structure
    cat > "$TOX_BOOTSTRAP_INFO_FILE" << EOF
{
  "nodes": [
    {
      "ipv4": "$local_ip",
      "port": $TOX_PORT,
      "public_key": "$public_key",
      "maintainer": "$TOX_LOCAL_NODE_NAME",
      "location": "$TOX_LOCAL_NODE_LOCATION",
      "status_udp": true,
      "status_tcp": true,
      "local": true
    }
EOF

    # Add public IP if different from local IP
    if [ -n "$public_ip" ] && [ "$public_ip" != "$local_ip" ]; then
        cat >> "$TOX_BOOTSTRAP_INFO_FILE" << EOF
    ,{
      "ipv4": "$public_ip",
      "port": $TOX_PORT,
      "public_key": "$public_key",
      "maintainer": "$TOX_LOCAL_NODE_NAME",
      "location": "$TOX_LOCAL_NODE_LOCATION (Public)",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    }
EOF
    fi

    # Add public bootstrap nodes if enabled
    if [ "$TOX_ENABLE_PUBLIC_BOOTSTRAP" = "true" ]; then
        cat >> "$TOX_BOOTSTRAP_INFO_FILE" << EOF
    ,{
      "ipv4": "node.tox.biribiri.org",
      "port": 33445,
      "public_key": "F404ABAA1C99A9D37D61AB54898F56793E1DEF8BD46B1038B9D822E8460FAB67",
      "maintainer": "nurupo",
      "location": "Netherlands",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    },
    {
      "ipv4": "tox.verdict.gg",
      "port": 33445,
      "public_key": "1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976",
      "maintainer": "Martin Schröder",
      "location": "Germany",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    },
    {
      "ipv4": "tox.initramfs.io",
      "port": 33445,
      "public_key": "3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25",
      "maintainer": "initramfs",
      "location": "United States",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    },
    {
      "ipv4": "bootstrap.tox.chat",
      "port": 33445,
      "public_key": "6FC41E2BD381D37E9748FC0E0328CE086AF9598BECC8FEB7DDF2E440475F300E",
      "maintainer": "Tox Foundation",
      "location": "Global",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    },
    {
      "ipv4": "95.31.18.227",
      "port": 33445,
      "public_key": "257744DBF57BE3E117FE05D145B5F806089428D4DCE4E3D0D50616AA16D417FF",
      "maintainer": "Anonymous",
      "location": "Russia",
      "status_udp": true,
      "status_tcp": true,
      "local": false
    }
EOF
    fi

    # Complete JSON structure
    cat >> "$TOX_BOOTSTRAP_INFO_FILE" << EOF
  ],
  "generated_at": "$timestamp",
  "local_node_info": {
    "name": "$TOX_LOCAL_NODE_NAME",
    "location": "$TOX_LOCAL_NODE_LOCATION",
    "public_key": "$public_key",
    "local_ip": "$local_ip",
    "public_ip": "$public_ip",
    "port": $TOX_PORT,
    "motd": "$TOX_MOTD"
  }
}
EOF

    log "Bootstrap info generated: $TOX_BOOTSTRAP_INFO_FILE"
}

# Background task to generate bootstrap info after daemon starts
generate_bootstrap_info_background() {
    if [ "$TOX_GENERATE_BOOTSTRAP_INFO" = "true" ]; then
        (
            sleep 5  # Give daemon time to start and generate keys
            generate_bootstrap_info
        ) &
    fi
}

# Main entrypoint logic
main() {
    log "Starting Tox Bootstrap Daemon..."
    
    # Handle user/group ID changes
    if [ "$TOX_USER_ID" != "1000" ] || [ "$TOX_GROUP_ID" != "1000" ]; then
        log "Updating user/group IDs to $TOX_USER_ID:$TOX_GROUP_ID"
        
        # Update group
        if [ "$TOX_GROUP_ID" != "1000" ]; then
            delgroup tox 2>/dev/null || true
            addgroup -g "$TOX_GROUP_ID" tox
        fi
        
        # Update user  
        if [ "$TOX_USER_ID" != "1000" ]; then
            deluser tox 2>/dev/null || true
            adduser -D -u "$TOX_USER_ID" -G tox tox
        fi
    fi
    
    # Ensure data directory exists and has correct permissions
    mkdir -p "$(dirname "$TOX_KEYS_FILE")"
    mkdir -p "$(dirname "$TOX_CONFIG_FILE")"
    mkdir -p "$(dirname "$TOX_BOOTSTRAP_INFO_FILE")"
    chown -R tox:tox /data
    
    # Note: tox-bootstrapd will generate keys automatically on first run if they don't exist
    if [ ! -f "$TOX_KEYS_FILE" ]; then
        log "Keys file doesn't exist - tox-bootstrapd will generate keys on startup"
    else
        log "Using existing keys: $TOX_KEYS_FILE"
    fi
    
    # Get log level number
    log_level_num=$(get_log_level_num)
    
    # Generate bootstrap nodes configuration
    bootstrap_nodes_config=$(generate_bootstrap_nodes)
    
    # Generate configuration file directly (avoid sed issues)
    log "Generating configuration file..."
    
    # Convert boolean values
    enable_ipv6=$(echo "$TOX_ENABLE_IPV6" | tr '[:upper:]' '[:lower:]')
    enable_lan_discovery=$(echo "$TOX_ENABLE_LAN_DISCOVERY" | tr '[:upper:]' '[:lower:]')
    enable_tcp_relay=$(echo "$TOX_ENABLE_TCP_RELAY" | tr '[:upper:]' '[:lower:]')
    enable_log_to_stdout=$(echo "$TOX_LOG_TO_STDOUT" | tr '[:upper:]' '[:lower:]')
    
    # Create config file directly
    cat > "$TOX_CONFIG_FILE" << EOF
// Tox bootstrap daemon configuration
// Generated by entrypoint.sh from environment variables

// The port to listen on (UDP and TCP)
port = $TOX_PORT

// Enable IPv6? (true/false)
enable_ipv6 = $enable_ipv6

// Enable LAN discovery? (true/false) 
enable_lan_discovery = $enable_lan_discovery

// Enable TCP relay? (true/false)
enable_tcp_relay = $enable_tcp_relay

// TCP relay ports (array of ports)
tcp_relay_ports = [$TOX_TCP_RELAY_PORTS]

// Path to the secret key file
keys_file_path = "$TOX_KEYS_FILE"

// Path to the PID file
pid_file_path = "$TOX_PID_FILE"

// Enable logging to stdout? (true/false)
enable_log_to_stdout = $enable_log_to_stdout

// Log level (2=INFO, 3=WARNING, 4=ERROR)
log_level = $log_level_num

// MOTD (Message of the Day)
motd = "$TOX_MOTD"

// Bootstrap nodes (only if TOX_ENABLE_PUBLIC_BOOTSTRAP=true)
bootstrap_nodes = (
$bootstrap_nodes_config
)
EOF
    
    # Set correct ownership
    chown tox:tox "$TOX_CONFIG_FILE"
    
    log "Configuration generated: $TOX_CONFIG_FILE"
    
    # Start background task to generate bootstrap info after daemon starts
    generate_bootstrap_info_background
    
    # Show network info
    local_ip=$(get_local_ip)
    
    log "Bootstrap node starting..."
    log "  Local IP: $local_ip"
    log "  Port: $TOX_PORT"
    log "  Config: $TOX_CONFIG_FILE"
    log "  Keys: $TOX_KEYS_FILE"
    log "  Bootstrap Info: $TOX_BOOTSTRAP_INFO_FILE"
    
    if [ "$TOX_ENABLE_PUBLIC_BOOTSTRAP" = "true" ]; then
        log "  Mode: Online (connected to public network)"
    else
        log "  Mode: Offline (local network only)"
    fi
    
    # Execute the tox-bootstrapd daemon as the tox user
    log "Starting tox-bootstrapd daemon..."
    exec su-exec tox:tox "$@"
}

# Run main function
main "$@"
