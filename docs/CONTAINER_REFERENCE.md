# Container Build Reference

## GitHub Actions vs Docker Hub Containers

### Ubuntu Versions

| GitHub Actions | Docker Hub Image | Ubuntu Version | Status |
|----------------|------------------|----------------|--------|
| `ubuntu-latest` | `ubuntu:24.04` | Noble Numbat | Current (Nov 2025) |
| `ubuntu-24.04` | `ubuntu:24.04` | Noble Numbat | LTS until 2029 |
| `ubuntu-22.04` | `ubuntu:22.04` | Jammy Jellyfish | LTS until 2027 |
| `ubuntu-20.04` | `ubuntu:20.04` | Focal Fossa | LTS until 2025 |

**Official Source:**
- https://github.com/actions/runner-images
- https://hub.docker.com/_/ubuntu

### Debian Versions

| GitHub Actions | Docker Hub Image | Debian Version | Catch2 Version |
|----------------|------------------|----------------|----------------|
| `debian:stable` | `debian:bookworm-slim` | Debian 12 | v2.13.10 |
| `debian:testing` | `debian:trixie-slim` | Debian 13 | v3.7.1 |
| N/A | `debian:sid-slim` | Unstable | v3.x (latest) |

**Official Source:**
- https://hub.docker.com/_/debian

### Catch2 Package Availability

```bash
# Debian Bookworm
container: debian:bookworm-slim
catch2 package: 2.13.10-1 (v2.x - header-only)
install: apt-get install -y catch2

# Debian Trixie
container: debian:trixie-slim
catch2 package: 3.7.1-0.5 (v3.x - requires linking)
install: apt-get install -y libcatch2-dev

# Ubuntu 24.04 (Noble)
container: ubuntu:24.04
catch2 package: 3.4.0-1 (v3.x)
install: apt-get install -y catch-dev or libcatch2-dev
```

## Local Build Commands

### Using Podman (Recommended)

```bash
# Automated builds (all containers)
./build-local-containers.sh

# Interactive shell
./build-interactive.sh

# Manual single container
podman run --rm -it \
    -v $(pwd):/workspace:Z \
    -w /workspace \
    debian:bookworm-slim \
    bash

# Then inside container:
apt-get update
apt-get install -y g++-12 make libboost-all-dev libtiff-dev catch2
cd Cell2Fire
make clean && make
make tests
```

### Using Docker

Replace `podman` with `docker` and remove `:Z` from volume mount:

```bash
docker run --rm -it \
    -v $(pwd):/workspace \
    -w /workspace \
    debian:trixie-slim \
    bash
```

## Workflow Container Mapping

### Current Workflow: build-debian-stable.yml

```yaml
strategy:
  matrix:
    debian_version: [bookworm, trixie]

container: debian:${{ matrix.debian_version }}-slim
```

**Maps to:**
- Job 1: `docker.io/library/debian:bookworm-slim`
- Job 2: `docker.io/library/debian:trixie-slim`

### Current Workflow: build-ubuntu-latest.yml

```yaml
runs-on: ubuntu-latest
```

**Maps to:**
- GitHub-hosted runner with Ubuntu 24.04 (Noble)
- Equivalent local: `ubuntu:24.04`

### Proposed: Single consolidated workflow

```yaml
strategy:
  matrix:
    container:
      - debian:bookworm-slim
      - debian:trixie-slim
      - ubuntu:24.04

container: ${{ matrix.container }}
```

## Testing Locally Before CI

```bash
# Test all containers match CI
./build-local-containers.sh

# Test specific container interactively
./build-interactive.sh
# Select: debian:trixie-slim

# Inside container, run same steps as CI:
apt-get update
apt-get install -y g++-12 make libboost-all-dev libtiff-dev catch2
cd Cell2Fire
make clean && make
make tests
cd ../test
bash test.sh
```

## Checking Container Versions

```bash
# Check what's in a container
podman run --rm debian:bookworm-slim cat /etc/os-release
podman run --rm ubuntu:24.04 lsb_release -a

# Check Catch2 version
podman run --rm debian:bookworm-slim bash -c \
    "apt-get update -qq && apt-cache show catch2 | grep Version"

podman run --rm debian:trixie-slim bash -c \
    "apt-get update -qq && apt-cache show libcatch2-dev | grep Version"
```

## Container Registry Sources

All images pull from Docker Hub by default:

```
debian:bookworm-slim    → docker.io/library/debian:bookworm-slim
ubuntu:24.04            → docker.io/library/ubuntu:24.04
```

**Other registries (if needed):**
```yaml
# GitHub Container Registry
container: ghcr.io/owner/image:tag

# Red Hat Quay
container: quay.io/centos/centos:stream9

# Custom registry
container: registry.example.com/image:tag
```

## GitHub Actions ubuntu-latest History

| Date | Version | Codename |
|------|---------|----------|
| 2024+ | 24.04 | Noble |
| 2022-2024 | 22.04 | Jammy |
| 2020-2022 | 20.04 | Focal |
| 2018-2020 | 18.04 | Bionic |

**Source:** https://github.com/actions/runner-images/blob/main/README.md
