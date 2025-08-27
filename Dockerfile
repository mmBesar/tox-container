# Multi-stage build for minimal runtime container
FROM alpine:3.18 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    pkgconfig \
    libsodium-dev \
    opus-dev \
    libvpx-dev \
    libconfig-dev \
    linux-headers

# Set working directory
WORKDIR /build

# Copy source code
COPY . .

# Initialize submodules if not already done
RUN git submodule update --init --recursive || true

# Configure and build
RUN mkdir -p _build && cd _build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DBUILD_TOXAV=ON \
        -DENABLE_STATIC=OFF \
        -DENABLE_SHARED=ON \
        -DBOOTSTRAP_DAEMON=ON \
        -DAUTOTEST=OFF \
        -DBUILD_MISC_TESTS=OFF \
        -DBUILD_FUN_UTILS=OFF && \
    make -j$(nproc) && \
    make install DESTDIR=/toxcore-install

# Runtime stage - minimal Alpine image
FROM alpine:3.18

LABEL maintainer="Local Toxcore Network" \
      description="Lightweight Toxcore bootstrap daemon for local networks" \
      version="latest"

# Install runtime dependencies only
RUN apk add --no-cache \
    libsodium \
    opus \
    libvpx \
    libconfig \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Copy built toxcore from builder stage
COPY --from=builder /toxcore-install/usr/local /usr/local

# Create toxcore user and directories
RUN adduser -D -s /bin/sh toxcore && \
    mkdir -p /var/lib/tox-bootstrapd /var/log/tox-bootstrapd /etc/tox-bootstrapd && \
    chown -R toxcore:toxcore /var/lib/tox-bootstrapd /var/log/tox-bootstrapd /etc/tox-bootstrapd

# Copy configuration and entrypoint
COPY config/tox-bootstrapd.conf /etc/tox-bootstrapd/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports for DHT
EXPOSE 33445/tcp 33445/udp

# Use non-root user
USER toxcore

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pidof tox-bootstrapd || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tox-bootstrapd", "--foreground", "--config", "/etc/tox-bootstrapd/tox-bootstrapd.conf"]
