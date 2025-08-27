FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    libsodium-dev \
    pkgconfig

# Build toxcore with minimal dependencies (following TokTok patterns)
WORKDIR /src
COPY --from=upstream . .

# Initialize submodules and configure build (minimal bootstrap-only build)
RUN git submodule update --init --recursive && \
    mkdir _build && \
    cd _build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DENABLE_STATIC=ON \
        -DBUILD_TESTING=OFF \
        -DMUST_BUILD_TOXAV=OFF \
        -DBOOTSTRAP_DAEMON=ON && \
    make -j"$(nproc)" tox-bootstrapd && \
    strip other/bootstrap_daemon/tox-bootstrapd

# Runtime stage - ultra minimal
FROM alpine:3.19

# Only essential runtime dependencies
RUN apk add --no-cache \
    libsodium \
    tini && \
    addgroup -g 1000 tox && \
    adduser -D -u 1000 -G tox -h /var/lib/tox-bootstrapd -s /bin/sh tox

# Copy only the static binary
COPY --from=builder /src/_build/other/bootstrap_daemon/tox-bootstrapd /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directories with correct permissions
RUN mkdir -p /var/lib/tox-bootstrapd /etc/tox-bootstrapd && \
    chown -R tox:tox /var/lib/tox-bootstrapd

# Expose standard Tox ports
EXPOSE 33445/tcp 33445/udp

# Use tini for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]

# Metadata
LABEL org.opencontainers.image.title="Tox Bootstrap Node" \
      org.opencontainers.image.description="Minimal Tox bootstrap daemon for local networks" \
      org.opencontainers.image.source="https://github.com/TokTok/c-toxcore"
