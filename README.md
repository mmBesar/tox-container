# Tox Bootstrap Node Container

🚧 **WORK IN PROGRESS** 🚧

This repository is currently under active development and **not ready for production use**.

## Current Status

### ✅ Working
- Multi-architecture container builds (arm64/amd64)
- Basic tox-bootstrapd compilation and packaging
- GitHub Actions CI/CD pipeline
- Docker Compose configuration templates

### ⚠️ Known Issues
- DHT key generation showing "Invalid argument" warnings
- Bootstrap info JSON file not being generated correctly
- Incomplete startup logging and error handling
- Container restart loops in some configurations

### 🔨 In Development
- Stable key generation process
- Bootstrap node auto-configuration for aTox clients
- Comprehensive environment variable configuration
- Network connectivity validation
- Documentation and usage examples

## What This Will Be

A lightweight, Pi4-optimized Tox bootstrap node container that:

- **Bridges local and internet Tox clients** - Connect local devices when internet is down, bridge to global network when online
- **Auto-configures Tox clients** - Generates `bootstrap_info.json` for easy import into aTox and other clients  
- **Highly configurable** - Control all aspects via environment variables
- **Persistent** - Maintains DHT keys and network state across restarts
- **Multi-architecture** - Native builds for x64 and ARM64 (Pi4 ready)

## Quick Start (When Ready)

**Note:** This doesn't work reliably yet. Use for testing only.

```bash
# Clone repository
git clone https://github.com/mmBesar/tox-container.git
cd tox-container

# Update docker-compose.yml with your settings
# Edit: image name, user IDs, paths, etc.

# Start the bootstrap node
docker-compose up -d

# Check logs (will show errors currently)
docker-compose logs -f tox

# Check generated files (may be missing)
ls -la ./tox-data/
```

## Repository Structure

```
├── Dockerfile                           # Multi-stage Alpine container build
├── entrypoint.sh                        # Configuration generator and startup script
├── docker-compose.yml                   # Comprehensive deployment example
├── .github/workflows/build-and-publish.yml  # Multi-arch CI/CD pipeline
└── README.md                           # This file
```

## Build Process

The container builds from the `upstream` branch which is synchronized with [TokTok/c-toxcore](https://github.com/TokTok/c-toxcore) master branch.

```bash
# Branches
main     - Docker files, CI/CD, documentation  
upstream - c-toxcore source code (synced with TokTok/c-toxcore)
```

## Contributing

This is a personal project for learning Docker containerization and Tox network deployment. 

**Current Focus:**
1. Fix DHT key generation issues
2. Implement reliable bootstrap info JSON generation  
3. Add comprehensive error handling and logging
4. Test on actual Pi4 hardware
5. Create usage documentation

## Roadmap

- [ ] **Phase 1**: Basic functionality (stable container startup)
- [ ] **Phase 2**: Client auto-configuration (working bootstrap_info.json)  
- [ ] **Phase 3**: Advanced features (monitoring, health checks)
- [ ] **Phase 4**: Documentation and examples
- [ ] **Phase 5**: Production readiness

## Contact

This is an experimental project. Use at your own risk.

**Expected Timeline:** Ready for testing by end of September 2025.

---

⚠️ **WARNING**: This container is not stable. It may fail to start, lose data, or behave unpredictably. Wait for a stable release before using in any important scenarios.
