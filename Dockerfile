FROM alpine:3.19 as builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    libsodium-dev \
    linux-headers \
    pkgconfig

# Clone and build toxcore from upstream branch
WORKDIR /build
COPY --from=upstream . /build/

# Build toxcore with bootstrap daemon
RUN mkdir _build && cd _build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_STATIC=OFF \
        -DBUILD_TESTING=OFF \
        -DMUST_BUILD_TOXAV=OFF \
        -DBOOTSTRAP_DAEMON=ON && \
    make -j$(nproc) tox-bootstrapd

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    libsodium \
    su-exec \
    tini

# Create tox user and directories
RUN addgroup -g 1000 tox && \
    adduser -D -u 1000 -G tox -h /var/lib/tox-bootstrapd tox && \
    mkdir -p /var/lib/tox-bootstrapd /etc/tox-bootstrapd && \
    chown -R tox:tox /var/lib/tox-bootstrapd

# Copy bootstrap daemon binary
COPY --from=builder /build/_build/other/bootstrap_daemon/tox-bootstrapd /usr/local/bin/

# Copy configuration and entrypoint
COPY config/tox-bootstrapd.conf /etc/tox-bootstrapd/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -tuln | grep :33445 || exit 1

# Expose ports
EXPOSE 33445/tcp 33445/udp

# Use tini as PID 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]

# Labels
LABEL org.opencontainers.image.title="Tox Bootstrap Node" \
      org.opencontainers.image.description="Lightweight Tox bootstrap daemon for decentralized communication" \
      org.opencontainers.image.source="https://github.com/TokTok/c-toxcore" \
      org.opencontainers.image.vendor="Your Name" \
      org.opencontainers.image.licenses="GPL-3.0"
