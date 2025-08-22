#!/bin/sh
set -e

# Default configuration
TOX_USER=${TOX_USER:-tox}
TOX_GROUP=${TOX_GROUP:-tox}
TOX_UID=${TOX_UID:-1000}
TOX_GID=${TOX_GID:-1000}
TOX_DATA_DIR=${TOX_DATA_DIR:-/var/lib/tox-bootstrapd}
TOX_CONFIG=${TOX_CONFIG:-/etc/tox-bootstrapd/tox-bootstrapd.conf}
TOX_LOG_LEVEL=${TOX_LOG_LEVEL:-info}
TOX_PORT=${TOX_PORT:-33445}
TOX_MOTD=${TOX_MOTD:-"Tox Bootstrap Node - Stay connected!"}

# Ensure data directory exists and has correct permissions
mkdir -p "$TOX_DATA_DIR"
chown -R "$TOX_UID:$TOX_GID" "$TOX_DATA_DIR"

# Generate keys if they don't exist
if [ ! -f "$TOX_DATA_DIR/keys" ]; then
    echo "Generating new bootstrap keys..."
    su-exec "$TOX_UID:$TOX_GID" tox-bootstrapd --keys-file="$TOX_DATA_DIR/keys" --generate-keys
    echo "Keys generated successfully!"
fi

# Create runtime config from template
cat > /tmp/tox-bootstrapd.conf << EOF
// Tox Bootstrap Daemon Configuration
port = $TOX_PORT
keys_file_path = "$TOX_DATA_DIR/keys"
pid_file_path = "$TOX_DATA_DIR/tox-bootstrapd.pid"
enable_ipv6 = true
enable_ipv4_fallback = true
enable_lan_discovery = true
enable_tcp_relay = true
tcp_relay_ports = [443, 3389, $TOX_PORT]
enable_motd = true
motd = "$TOX_MOTD"

// Bootstrap nodes - these are public bootstrap nodes
bootstrap_nodes = (
    { // Tox1
        address = "tox.verdict.gg"
        port = 33445
        public_key = "1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976"
    },
    { // Tox2  
        address = "tox2.abilinski.com"
        port = 33445
        public_key = "7A6098B590BDC73F9723FC59F82B3F9085A64D1B213AAF8E610FD351930D052D"
    },
    { // Tox3
        address = "tox.plastiras.org"
        port = 33445
        public_key = "8E8B63299B3D520FB377FE5100E65E3322F7AE5B20A0ACED2981769FC5B43725"
    }
)
EOF

# Show bootstrap info on startup
echo "============================================="
echo "Tox Bootstrap Node Starting"
echo "============================================="
echo "Port: $TOX_PORT (TCP/UDP)"
echo "Data Directory: $TOX_DATA_DIR"
echo "Log Level: $TOX_LOG_LEVEL"
echo "MOTD: $TOX_MOTD"
echo "User: $TOX_UID:$TOX_GID"

# Get and display public key
if [ -f "$TOX_DATA_DIR/keys" ]; then
    echo "---------------------------------------------"
    echo "Bootstrap Node Info:"
    # Extract public key (first 64 chars of the keys file when hex-dumped)
    PUBLIC_KEY=$(su-exec "$TOX_UID:$TOX_GID" od -A n -t x1 -j 0 -N 32 "$TOX_DATA_DIR/keys" | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
    echo "Public Key: $PUBLIC_KEY"
    echo "Add this node to your Tox client:"
    echo "  Address: <your-server-ip>"
    echo "  Port: $TOX_PORT"  
    echo "  Public Key: $PUBLIC_KEY"
    echo "---------------------------------------------"
fi

echo "Starting tox-bootstrapd..."
echo "============================================="

# Start the daemon
exec su-exec "$TOX_UID:$TOX_GID" tox-bootstrapd \
    --config="/tmp/tox-bootstrapd.conf" \
    --log-backend=stdout \
    --foreground
