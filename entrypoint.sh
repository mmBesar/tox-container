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

# Check if we're running as root
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, will use su-exec to drop privileges"
    USE_SU_EXEC=true
    
    # Ensure data directory exists and has correct permissions
    mkdir -p "$TOX_DATA_DIR"
    chown -R "$TOX_UID:$TOX_GID" "$TOX_DATA_DIR"
    
    # Ensure tox user exists with correct UID/GID
    if ! getent group "$TOX_GID" > /dev/null 2>&1; then
        addgroup -g "$TOX_GID" "$TOX_GROUP"
    fi
    if ! getent passwd "$TOX_UID" > /dev/null 2>&1; then
        adduser -D -u "$TOX_UID" -G "$TOX_GROUP" -h "$TOX_DATA_DIR" "$TOX_USER"
    fi
else
    echo "Running as user $(id -u):$(id -g), no privilege dropping needed"
    USE_SU_EXEC=false
    
    # Just ensure data directory exists (permissions should already be correct from volume mount)
    mkdir -p "$TOX_DATA_DIR"
fi

# Generate keys if they don't exist
if [ ! -f "$TOX_DATA_DIR/keys" ]; then
    echo "Generating new bootstrap keys..."
    if [ "$USE_SU_EXEC" = "true" ]; then
        su-exec "$TOX_UID:$TOX_GID" tox-bootstrapd --keys-file="$TOX_DATA_DIR/keys" --generate-keys
    else
        tox-bootstrapd --keys-file="$TOX_DATA_DIR/keys" --generate-keys
    fi
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
echo "User: $(id -u):$(id -g)"
echo "Use su-exec: $USE_SU_EXEC"

# Get and display public key
if [ -f "$TOX_DATA_DIR/keys" ]; then
    echo "---------------------------------------------"
    echo "Bootstrap Node Info:"
    # Extract public key (first 64 chars of the keys file when hex-dumped)
    if [ "$USE_SU_EXEC" = "true" ]; then
        PUBLIC_KEY=$(su-exec "$TOX_UID:$TOX_GID" od -A n -t x1 -j 0 -N 32 "$TOX_DATA_DIR/keys" | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
    else
        PUBLIC_KEY=$(od -A n -t x1 -j 0 -N 32 "$TOX_DATA_DIR/keys" | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
    fi
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
if [ "$USE_SU_EXEC" = "true" ]; then
    exec su-exec "$TOX_UID:$TOX_GID" tox-bootstrapd \
        --config="/tmp/tox-bootstrapd.conf" \
        --log-backend=stdout \
        --foreground
else
    exec tox-bootstrapd \
        --config="/tmp/tox-bootstrapd.conf" \
        --log-backend=stdout \
        --foreground
fi
