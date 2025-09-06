# Multi-stage build for c-toxcore DHT bootstrap node
# Supports arm64 and amd64 architectures

# Build stage
FROM alpine:3.20 as builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    ninja \
    git \
    pkgconfig \
    libsodium-dev \
    libsodium-static \
    linux-headers

# Create build directory
WORKDIR /build

# Copy source code (will be from upstream branch in CI)
COPY . /build/

# Initialize git submodules if present
RUN if [ -f .gitmodules ]; then \
        git submodule update --init --recursive || true; \
    fi

# Configure CMake build
# Focus only on DHT_bootstrap with minimal dependencies
RUN cmake -B _build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_SHARED=OFF \
    -DENABLE_STATIC=ON \
    -DBUILD_TOXAV=OFF \
    -DMUST_BUILD_TOXAV=OFF \
    -DBOOTSTRAP_DAEMON=OFF \
    -DDHT_BOOTSTRAP=ON \
    -DAUTOTEST=OFF \
    -DUNITTEST=OFF \
    -DBUILD_MISC_TESTS=OFF \
    -DBUILD_FUN_UTILS=OFF \
    -DSTRICT_ABI=ON

# Build the project
RUN cmake --build _build --parallel $(nproc) --target DHT_bootstrap

# Verify the binary was built
RUN ls -la _build/other/bootstrap_daemon/DHT_bootstrap

# Runtime stage - minimal Alpine image
FROM alpine:3.20

# Build metadata
ARG BUILD_DATE
ARG VCS_REF
LABEL org.opencontainers.image.created=$BUILD_DATE \
      org.opencontainers.image.source="https://github.com/TokTok/c-toxcore" \
      org.opencontainers.image.version=$VCS_REF \
      org.opencontainers.image.description="Tox DHT Bootstrap Node - Decentralized P2P networking" \
      org.opencontainers.image.title="Tox DHT Bootstrap"

# Install minimal runtime dependencies
RUN apk add --no-cache \
    libsodium \
    su-exec \
    tini

# Create non-root user
RUN addgroup -g 1000 -S toxcore && \
    adduser -u 1000 -S toxcore -G toxcore

# Copy the DHT_bootstrap binary from builder stage
COPY --from=builder /build/_build/other/bootstrap_daemon/DHT_bootstrap /usr/local/bin/DHT_bootstrap

# Ensure binary is executable and test it
RUN chmod +x /usr/local/bin/DHT_bootstrap && \
    /usr/local/bin/DHT_bootstrap --help || echo "DHT_bootstrap binary ready"

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create data directory for persistent keys
RUN mkdir -p /data && chown toxcore:toxcore /data

# Expose both TCP and UDP on port 33445 (default Tox DHT port)
EXPOSE 33445/tcp 33445/udp

# Set default environment variables
ENV TOX_PORT=33445 \
    TOX_ENABLE_INTERNET=true \
    TOX_KEYS_FILE=/data/keys \
    TOX_LOG_LEVEL=INFO \
    TOX_MOTD="Tox DHT Bootstrap Node"

# Use tini as init system for proper signal handling
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default user (can be overridden with --user)
USER toxcore

# Volume for persistent data
VOLUME ["/data"]

# Health check - verify the port is listening
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD netstat -ln | grep -q ":${TOX_PORT:-33445}" || exit 1
