#!/bin/sh
set -e

# Configuration defaults
TOX_DATA_DIR="${TOX_DATA_DIR:-/var/lib/tox-bootstrapd}"
TOX_PORT="${TOX_PORT:-33445}"
TOX_MOTD="${TOX_MOTD:-Tox Bootstrap Node}"

echo "=== Tox Bootstrap Node ==="

# Ensure we're running as the tox user (container should be started with --user tox)
if [ "$(id -u)" != "1000" ]; then
    echo "ERROR: Container must be run with --user 1000:1000"
    echo "Usage: docker run --user 1000:1000 -p 33445:33445 -p 33445:33445/udp <image>"
    exit 1
fi

# Ensure data directory exists
mkdir -p "$TOX_DATA_DIR"
cd "$TOX_DATA_DIR"

# Generate keys if they don't exist
if [ ! -f keys ]; then
    echo "Generating bootstrap keys..."
    tox-bootstrapd --keys-file=keys --generate-keys
    echo "Keys generated successfully!"
fi

# Create minimal runtime config
cat > tox-bootstrapd.conf << EOF
// Minimal tox-bootstrapd configuration for local networks
port = $TOX_PORT
keys_file_path = "$TOX_DATA_DIR/keys"
pid_file_path = "$TOX_DATA_DIR/tox-bootstrapd.pid"

// Network settings
enable_ipv6 = true
enable_ipv4_fallback = true
enable_lan_discovery = true
enable_tcp_relay = true
tcp_relay_ports = [$TOX_PORT]

// MOTD
enable_motd = true
motd = "$TOX_MOTD"

// Bootstrap from public nodes (minimal list for local networks)
bootstrap_nodes = (
    {
        address = "tox.verdict.gg"
        port = 33445
        public_key = "1C5293AEF2114717547B39DA8EA6F1E331E5E358B35F9B6B5F19317911C5F976"
    },
    {
        address = "bootstrap.tox.chat"
        port = 33445
        public_key = "3F0A45A268367C1BEA652F258C85F4A66DA76BCAA667A49E770BCC4917AB6A25"
    }
)
EOF

# Display node information
if [ -f keys ]; then
    echo "=== Node Information ==="
    echo "Port: $TOX_PORT (TCP/UDP)"
    echo "Data: $TOX_DATA_DIR"
    echo "MOTD: $TOX_MOTD"
    
    # Extract and display public key
    PUBLIC_KEY=$(od -A n -t x1 -j 0 -N 32 keys | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
    echo "Public Key: $PUBLIC_KEY"
    echo ""
    echo "Add this node to your Tox client:"
    echo "  Address: <your-server-ip>"
    echo "  Port: $TOX_PORT"
    echo "  Public Key: $PUBLIC_KEY"
    echo "========================="
fi

echo "Starting tox-bootstrapd..."

# Start the daemon in foreground mode
exec tox-bootstrapd \
    --config="$TOX_DATA_DIR/tox-bootstrapd.conf" \
    --log-backend=stdout \
    --foreground
