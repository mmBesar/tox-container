#!/bin/sh
set -e

# Environment variables with defaults
TOX_LOG_LEVEL=${TOX_LOG_LEVEL:-"INFO"}
TOX_LOG_BACKEND=${TOX_LOG_BACKEND:-"stdout"}
TOX_PORT_TCP=${TOX_PORT_TCP:-"33445"}
TOX_PORT_UDP=${TOX_PORT_UDP:-"33445"}
TOX_KEYS_FILE=${TOX_KEYS_FILE:-"/var/lib/tox-bootstrapd/keys"}
TOX_PID_FILE=${TOX_PID_FILE:-"/var/lib/tox-bootstrapd/tox-bootstrapd.pid"}
TOX_LOG_FILE=${TOX_LOG_FILE:-"/var/log/tox-bootstrapd/tox-bootstrapd.log"}

# Function to generate configuration if it doesn't exist
generate_config() {
    if [ ! -f /etc/tox-bootstrapd/tox-bootstrapd.conf ]; then
        echo "Generating default configuration..."
        cat > /etc/tox-bootstrapd/tox-bootstrapd.conf << EOF
// Tox Bootstrap Daemon Configuration for Local Network
// Listening ports
port = $TOX_PORT_TCP
udp_port = $TOX_PORT_UDP

// Key storage
keys_file_path = "$TOX_KEYS_FILE"
pid_file_path = "$TOX_PID_FILE"

// Logging
enable_log = true
log_level = "$TOX_LOG_LEVEL"
log_backend = "$TOX_LOG_BACKEND"
log_file_path = "$TOX_LOG_FILE"

// Networking - Allow connections from local networks
enable_ipv6 = false
enable_ipv4_fallback = true
enable_lan_discovery = true
enable_hole_punching = true

// Performance tuning for local networks
motd = "Local Toxcore Bootstrap Node"
enable_motd = true

// Bootstrap nodes list (empty for local-only operation)
bootstrap_nodes = (
    // Add your bootstrap nodes here if needed
    // { address = "node.tox.biribiri.org", port = 33445, public_key = "F404ABAA1C99A9D37D61AB54898F56793E1DEF8BD46B1038B9D822E8460FAB67" }
)
EOF
        echo "Configuration generated at /etc/tox-bootstrapd/tox-bootstrapd.conf"
    fi
}

# Function to display node info
show_node_info() {
    if [ -f "$TOX_KEYS_FILE" ]; then
        echo "==================================="
        echo "TOX BOOTSTRAP NODE INFORMATION"
        echo "==================================="
        echo "TCP Port: $TOX_PORT_TCP"
        echo "UDP Port: $TOX_PORT_UDP"
        echo "Keys File: $TOX_KEYS_FILE"
        echo "Log Level: $TOX_LOG_LEVEL"
        echo "==================================="
        
        # Try to extract public key if possible
        if command -v xxd >/dev/null 2>&1 && [ -f "$TOX_KEYS_FILE" ]; then
            echo "Public Key (hex):"
            xxd -l 32 -p "$TOX_KEYS_FILE" | tr -d '\n'
            echo
            echo "==================================="
        fi
    fi
}

# Function to initialize directories and files
init_dirs() {
    # Ensure directories exist with correct permissions
    mkdir -p "$(dirname "$TOX_KEYS_FILE")"
    mkdir -p "$(dirname "$TOX_PID_FILE")"
    mkdir -p "$(dirname "$TOX_LOG_FILE")"
    
    # Create log file if it doesn't exist
    if [ ! -f "$TOX_LOG_FILE" ] && [ "$TOX_LOG_BACKEND" = "file" ]; then
        touch "$TOX_LOG_FILE"
    fi
}

# Handle signals
cleanup() {
    echo "Received termination signal, shutting down..."
    if [ -f "$TOX_PID_FILE" ]; then
        PID=$(cat "$TOX_PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill -TERM "$PID"
            wait "$PID" 2>/dev/null
        fi
        rm -f "$TOX_PID_FILE"
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT SIGQUIT

# Main execution
main() {
    echo "Starting Tox Bootstrap Daemon..."
    echo "Container: toxcore-local-$(date +%Y%m%d)"
    
    # Initialize
    init_dirs
    generate_config
    show_node_info
    
    # Execute the command
    if [ "$1" = "tox-bootstrapd" ]; then
        # Run tox-bootstrapd with provided arguments
        echo "Starting bootstrap daemon with: $*"
        exec "$@"
    else
        # Run custom command
        echo "Running custom command: $*"
        exec "$@"
    fi
}

# Special commands
case "$1" in
    "version")
        tox-bootstrapd --version
        exit 0
        ;;
    "config")
        generate_config
        cat /etc/tox-bootstrapd/tox-bootstrapd.conf
        exit 0
        ;;
    "info")
        show_node_info
        exit 0
        ;;
    "shell")
        exec /bin/sh
        ;;
    *)
        main "$@"
        ;;
esac
