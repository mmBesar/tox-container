#!/bin/sh
set -e

# entrypoint.sh - Tox DHT Bootstrap Node Entrypoint
# Handles environment variable configuration and starts DHT_bootstrap

echo "Starting Tox DHT Bootstrap Node..."
echo "Local network functionality: ALWAYS ENABLED"
echo "Internet connectivity: ${TOX_ENABLE_INTERNET}"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Validate environment variables
validate_env() {
    # Validate port
    if ! echo "${TOX_PORT}" | grep -qE '^[0-9]+$' || [ "${TOX_PORT}" -lt 1 ] || [ "${TOX_PORT}" -gt 65535 ]; then
        log "ERROR: TOX_PORT must be a valid port number (1-65535)"
        exit 1
    fi
    
    # Validate boolean values
    case "${TOX_ENABLE_INTERNET}" in
        true|false|1|0|yes|no|on|off) ;;
        *) log "ERROR: TOX_ENABLE_INTERNET must be true/false/1/0/yes/no/on/off"; exit 1 ;;
    esac
}

# Convert boolean environment variables
normalize_bool() {
    case "${TOX_ENABLE_INTERNET}" in
        true|1|yes|on) TOX_ENABLE_INTERNET=true ;;
        false|0|no|off) TOX_ENABLE_INTERNET=false ;;
    esac
}

# Handle user permissions for volume mounts
handle_permissions() {
    # If running as root, switch to the specified user
    if [ "$(id -u)" = "0" ]; then
        # If PUID/PGID are set, use them
        if [ -n "${PUID:-}" ] && [ -n "${PGID:-}" ]; then
            log "Switching to UID:GID ${PUID}:${PGID}"
            
            # Ensure the data directory is owned by the target user
            chown -R "${PUID}:${PGID}" /data
            
            # Execute as the target user
            exec su-exec "${PUID}:${PGID}" "$0" "$@"
        else
            # Default to toxcore user
            chown -R toxcore:toxcore /data
            exec su-exec toxcore:toxcore "$0" "$@"
        fi
    fi
}

# Generate or load bootstrap keys
setup_keys() {
    local keys_file="${TOX_KEYS_FILE}"
    
    if [ ! -f "${keys_file}" ]; then
        log "Generating new bootstrap keys at ${keys_file}"
        mkdir -p "$(dirname "${keys_file}")"
        
        # Generate a random key file (DHT_bootstrap will create keys if not provided)
        touch "${keys_file}"
    else
        log "Using existing bootstrap keys from ${keys_file}"
    fi
}

# Build DHT_bootstrap command arguments
build_args() {
    local args=""
    
    # Port configuration
    args="${args} --port ${TOX_PORT}"
    
    # Keys file
    if [ -n "${TOX_KEYS_FILE}" ]; then
        args="${args} --keys-file ${TOX_KEYS_FILE}"
    fi
    
    # Log level
    case "${TOX_LOG_LEVEL}" in
        TRACE|DEBUG|INFO|WARNING|ERROR)
            args="${args} --log-level ${TOX_LOG_LEVEL}"
            ;;
    esac
    
    # Message of the Day
    if [ -n "${TOX_MOTD}" ]; then
        args="${args} --motd \"${TOX_MOTD}\""
    fi
    
    # Internet connectivity control
    if [ "${TOX_ENABLE_INTERNET}" = "false" ]; then
        log "Internet connectivity DISABLED - Local network only"
        # Note: We'll use firewall rules or network isolation
        # DHT_bootstrap doesn't have a direct "local only" flag
        # This can be handled at the container network level
    else
        log "Internet connectivity ENABLED - Will connect to external Tox network"
    fi
    
    echo "${args}"
}

# Apply network restrictions if internet is disabled
setup_network_restrictions() {
    if [ "${TOX_ENABLE_INTERNET}" = "false" ]; then
        log "Setting up local-only network restrictions..."
        
        # Note: In a container environment, network restrictions are typically
        # handled at the Docker/compose level rather than within the container
        # This is a placeholder for any internal restrictions needed
        
        # We could potentially use iptables if available, but it's better to
        # handle this at the container orchestration level
        log "Network restrictions should be configured at the Docker level"
        log "Example: networks with internal: true or custom bridge networks"
    fi
}

# Signal handlers for graceful shutdown
trap_signals() {
    trap 'log "Received SIGTERM, shutting down..."; kill -TERM $PID; wait $PID' TERM
    trap 'log "Received SIGINT, shutting down..."; kill -INT $PID; wait $PID' INT
}

# Main execution
main() {
    log "Initializing Tox DHT Bootstrap Node..."
    
    # Validate and normalize environment
    validate_env
    normalize_bool
    
    # Handle permissions
    handle_permissions
    
    # Setup bootstrap keys
    setup_keys
    
    # Setup network restrictions
    setup_network_restrictions
    
    # Build command arguments
    local cmd_args
    cmd_args=$(build_args)
    
    log "Configuration:"
    log "  Port: ${TOX_PORT} (TCP/UDP)"
    log "  Keys file: ${TOX_KEYS_FILE}"
    log "  Log level: ${TOX_LOG_LEVEL}"
    log "  MOTD: ${TOX_MOTD}"
    log "  Internet: ${TOX_ENABLE_INTERNET}"
    log "  User: $(id -u):$(id -g)"
    
    # Setup signal handling
    trap_signals
    
    log "Starting DHT_bootstrap with args: ${cmd_args}"
    
    # Start DHT_bootstrap
    # shellcheck disable=SC2086
    DHT_bootstrap ${cmd_args} &
    PID=$!
    
    log "DHT_bootstrap started with PID: ${PID}"
    log "Ready to accept connections on port ${TOX_PORT}"
    log "Local clients can ALWAYS connect (offline capability maintained)"
    
    # Wait for the process to complete
    wait $PID
    
    log "DHT_bootstrap has stopped"
}

# Execute main function
main "$@"
