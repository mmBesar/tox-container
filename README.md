> # NOT READY YET!

# Tox Bootstrap Node Container

A lightweight, multi-architecture Docker container for running a Tox bootstrap node. Built from the official [TokTok/c-toxcore](https://github.com/TokTok/c-toxcore) repository with automatic upstream synchronization.

## Features

✅ **Multi-Architecture**: Supports AMD64 and ARM64 (perfect for Raspberry Pi 4)  
✅ **Auto-Updates**: Follows upstream releases and provides nightly builds  
✅ **Lightweight**: Alpine-based image (~50MB final size)  
✅ **Secure**: Runs as non-root user (1000:1000)  
✅ **Persistent**: Maintains keys and DHT state across restarts  
✅ **Configurable**: Easy customization via environment variables

## Quick Start

### Using Docker Compose (Recommended)

1. Update the image name in `docker-compose.yml`
2. Start the container:

```bash
docker-compose up -d
```

### Using Docker CLI

```bash
docker run -d \
  --name tox-bootstrap \
  -p 33445:33445/tcp \
  -p 33445:33445/udp \
  -v tox-data:/var/lib/tox-bootstrapd \
  --user 1000:1000 \
  --restart unless-stopped \
  ghcr.io/mmBesar/tox-container:latest
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TOX_PORT` | `33445` | Bootstrap node port (TCP/UDP) |
| `TOX_MOTD` | `Tox Bootstrap Node - Stay connected!` | Message of the day |
| `TOX_LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `TOX_UID` | `1000` | User ID to run as |
| `TOX_GID` | `1000` | Group ID to run as |

### Custom Configuration

You can mount a custom config file:

```bash
-v /path/to/your/tox-bootstrapd.conf:/etc/tox-bootstrapd/tox-bootstrapd.conf:ro
```

## Image Tags

- `latest` - Latest stable release
- `v0.2.x` - Specific version tags  
- `nightly` - Latest development build
- `nightly-YYYYMMDD` - Specific nightly build

## Connecting Your Tox Client

After starting the container, check the logs to get your bootstrap node info:

```bash
docker logs tox-bootstrap
```

Look for output like:
```
Bootstrap Node Info:
Public Key: 1234567890ABCDEF...
Add this node to your Tox client:
  Address: your-server-ip
  Port: 33445
  Public Key: 1234567890ABCDEF...
```

Add these details to your Tox client's bootstrap nodes list.

## Resource Usage

Perfect for Raspberry Pi 4:
- **Memory**: ~10-15MB RAM usage
- **CPU**: Minimal (mostly network I/O)
- **Storage**: <1GB total (including container)

## Building Locally

```bash
git clone https://github.com/mmBesar/tox-container
cd tox-container
docker build -t tox-bootstrap .
```

## Architecture

This repository maintains:
- `main` branch: Container configuration files
- `upstream` branch: Synchronized copy of TokTok/c-toxcore (updated daily)

### Automatic Builds

- **Stable builds**: Triggered when TokTok/c-toxcore releases new tags
- **Nightly builds**: Daily builds from upstream master branch
- **Multi-arch**: Builds for AMD64 and ARM64 automatically

## Monitoring

### Health Checks

The container includes health checks that verify the bootstrap daemon is listening on the configured port.

### Logs

View container logs:
```bash
docker logs -f tox-bootstrap
```

### Status

Check if your node is working:
```bash
# Check if port is listening
docker exec tox-bootstrap netstat -tuln | grep 33445

# View active connections  
docker exec tox-bootstrap ss -tuln | grep 33445
```

## Security

- Runs as non-root user (UID/GID 1000)
- Uses minimal Alpine base image
- No unnecessary packages or services
- Persistent storage only for node keys and DHT data

## Troubleshooting

### Container won't start
- Check port 33445 isn't already in use: `netstat -tuln | grep 33445`
- Verify user 1000:1000 has access to the data volume
- Check container logs: `docker logs tox-bootstrap`

### Can't connect to bootstrap node
- Verify your firewall allows UDP/TCP traffic on port 33445
- Ensure your router forwards port 33445 to your Pi4 (if behind NAT)
- Check the node is generating DHT traffic in logs

### Performance issues
- Monitor resource usage: `docker stats tox-bootstrap`
- Consider increasing memory limits for very busy nodes
- Check network connectivity to other bootstrap nodes

## Contributing

1. Fork this repository
2. Create a feature branch
3. Submit a pull request

The container will automatically rebuild when changes are pushed to main.

## License

This project follows the same license as TokTok/c-toxcore (GPL-3.0). See the upstream repository for full license details.

## Acknowledgments

- [TokTok/c-toxcore](https://github.com/TokTok/c-toxcore) - The core Tox protocol implementation
- [Tox Project](https://tox.chat) - Decentralized communication protocol
