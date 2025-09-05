# Use a minimal base image for both architectures
FROM alpine:3.18 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    autoconf \
    automake \
    libtool \
    check-dev \
    libsodium-dev \
    libconfig-dev \
    libopus-dev \
    libvpx-dev \
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    libswresample-dev \
    libswscale-dev \
    openssl-dev \
    python3

# Copy the source code from the upstream branch (will be built in context)
WORKDIR /tmp
COPY . /tmp/c-toxcore/

# Build with minimal features for reduced size
WORKDIR /tmp/c-toxcore
RUN mkdir build && cd build && \
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DBUILD_TESTING=OFF \
        -DBOOTSTRAP_DAEMON=OFF \
        -DDHT_BOOTSTRAP=OFF \
        -DUSE_IPV6=OFF \
        && \
    make -j$(nproc) && \
    make install

# Create final minimal image
FROM alpine:3.18

# Install runtime dependencies only
RUN apk add --no-cache \
    libsodium \
    libconfig \
    libopus \
    libvpx \
    libavutil \
    libavcodec \
    libavformat \
    libswresample \
    libswscale \
    openssl

# Copy built binaries from builder
COPY --from=builder /usr/bin/tox* /usr/bin/

# Create non-root user
RUN addgroup -g 1000 -S toxcore && \
    adduser -u 1000 -S toxcore -G toxcore

# Create data directory
RUN mkdir -p /data && chown toxcore:toxcore /data

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set environment variables with defaults
ENV TOXCORE_DATA_DIR=/data
ENV TOXCORE_PORT=33445
ENV TOXCORE_ENABLE_IPV6=false
ENV TOXCORE_ENABLE_TCP_RELAY=true
ENV TOXCORE_ENABLE_UDP_RELAY=true
ENV TOXCORE_LOG_LEVEL=INFO

# Expose default port
EXPOSE 33445

# Switch to non-root user
USER toxcore

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
