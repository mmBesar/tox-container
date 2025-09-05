#!/bin/sh
set -e

# Function to handle SIGTERM for graceful shutdown
graceful_shutdown() {
    echo "Received SIGTERM, shutting down gracefully..."
    exit 0
}

trap graceful_shutdown SIGTERM

# Set user and group from environment if provided
if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    echo "Setting user and group IDs: ${PUID}:${PGID}"
    deluser toxcore 2>/dev/null || true
    delgroup toxcore 2>/dev/null || true
    addgroup -g "${PGID}" -S toxcore
    adduser -u "${PUID}" -S toxcore -G toxcore
    chown -R "${PUID}:${PGID}" /data
fi

# Create data directory if it doesn't exist
mkdir -p "${TOXCORE_DATA_DIR}"

# Generate configuration if it doesn't exist
if [ ! -f "${TOXCORE_DATA_DIR}/tox-bootstrapd.conf" ]; then
    echo "Generating default configuration..."
    cat > "${TOXCORE_DATA_DIR}/tox-bootstrapd.conf" << EOF
[tox]
log_level = ${TOXCORE_LOG_LEVEL:-INFO}
pid_file_path = ${TOXCORE_DATA_DIR}/tox-bootstrapd.pid

[udp]
enable_ipv6 = ${TOXCORE_ENABLE_IPV6:-false}
enable_ipv4_fallback = true
port = ${TOXCORE_PORT:-33445}

[tcp]
enable_tcp = ${TOXCORE_ENABLE_TCP_RELAY:-true}
port = ${TOXCORE_PORT:-33445}

[bootstrap_nodes]
EOF
fi

# Set ownership of data directory
chown -R toxcore:toxcore "${TOXCORE_DATA_DIR}"

# Switch to non-root user if PUID/PGID are set
if [ -n "${PUID}" ] && [ -n "${PGID}" ]; then
    exec su-exec toxcore:toxcore "$@"
else
    exec "$@"
fi
