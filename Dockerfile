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

# Clone the upstream branch (source code)
# Note: In CI, this will be replaced by copying from the upstream branch
ARG TARGETARCH
COPY . /build/

# Initialize git submodules if present
RUN if [ -f .gitmodules ]; then \
        git submodule update --init --recursive || true; \
    fi

# Configure CMake build
# - Only build DHT_bootstrap (disable toxav, bootstrap daemon, etc.)
# - Static build for minimal runtime dependencies
# - Release build for optimization
# - Disable toxav dependencies (opus, vpx) completely
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
    -DFULLY_STATIC=ON \
    -DSTRICT_ABI=ON

# Build the project
RUN cmake --build _build --parallel $(nproc)

# Install to staging area
RUN cmake --build _build --target install

# Runtime stage - minimal Alpine image
FROM alpine:3.20

# Install runtime dependencies (minimal)
RUN apk add --no-cache \
    libsodium \
    su-exec \
    tini

# Create non-root user
RUN addgroup -g 1000 -S toxcore && \
    adduser -u 1000 -S toxcore -G toxcore

# Copy the DHT_bootstrap binary and required libraries from builder stage
COPY --from=builder /usr/local/bin/DHT_bootstrap /usr/local/bin/DHT_bootstrap
COPY --from=builder /usr/local/lib/libtoxcore.so* /usr/local/lib/
COPY --from=builder /usr/lib/libsodium.so* /usr/lib/

# Ensure binary is executable
RUN chmod +x /usr/local/bin/DHT_bootstrap

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create data directory for persistent keys
RUN mkdir -p /data && chown toxcore:toxcore /data

# Expose both TCP and UDP on port 33445
EXPOSE 33445/tcp 33445/udp

# Set default environment variables
ENV TOX_PORT=33445
ENV TOX_ENABLE_INTERNET=true

# Use tini as init system
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]

# Default user (can be overridden with --user in docker-compose)
USER toxcore

# Volume for persistent data
VOLUME ["/data"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -ln | grep -q ":${TOX_PORT:-33445}" || exit 1
