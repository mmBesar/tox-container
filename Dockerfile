FROM alpine:3.19 as builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    libsodium-dev \
    libconfig-dev \
    linux-headers \
    pkgconfig

# Clone and build toxcore from upstream branch
WORKDIR /build
COPY --from=upstream . /build/

# Initialize git submodules and build toxcore with bootstrap daemon
RUN git submodule update --init --recursive && \
    mkdir _build && cd _build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_STATIC=OFF \
        -DBUILD_TESTING=OFF \
        -DMUST_BUILD_TOXAV=OFF \
        -DBOOTSTRAP_DAEMON=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local && \
    make -j$(nproc) && \
    make install && \
    echo "Installed files:" && \
    find /usr/local -name "*tox*" && \
    echo "Bootstrap daemon dependencies:" && \
    ldd /usr/local/bin/tox-bootstrapd

# Runtime stage
FROM alpine:3.19

# Install runtime dependencies - IMPORTANT: Use -dev packages to get .so files
RUN apk add --no-cache \
    libsodium-dev \
    libconfig-dev \
    su-exec \
    tini

# Create tox user and directories
RUN addgroup -g 1000 tox && \
    adduser -D -u 1000 -G tox -h /var/lib/tox-bootstrapd tox && \
    mkdir -p /var/lib/tox-bootstrapd /etc/tox-bootstrapd && \
    chown -R tox:tox /var/lib/tox-bootstrapd

# Copy the complete installation from builder (binaries + libraries)
COPY --from=builder /usr/local/ /usr/local/

# Update library cache so the system can find libtoxcore.so.2
RUN echo "/usr/local/lib" >> /etc/ld-musl-aarch64.path && \
    echo "/usr/local/lib" >> /etc/ld-musl-x86_64.path && \
    ldconfig || true

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
      org.opencontainers.image.vendor="mbesar" \
      org.opencontainers.image.licenses="GPL-3.0"
