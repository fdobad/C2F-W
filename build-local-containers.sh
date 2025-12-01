#!/usr/bin/env bash
set -euo pipefail

# Local container build script for Cell2Fire
# Matches GitHub Actions build-debian-stable.yml workflow

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Container images to build with
CONTAINERS=(
    "docker.io/library/debian:bookworm-slim"
    "docker.io/library/debian:trixie-slim"
    "docker.io/library/ubuntu:22.04"  # jammy
    "docker.io/library/ubuntu:24.04"  # noble latest 2025-11
)

# Build output directory
OUTPUT_DIR="${SCRIPT_DIR}/build-output"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}=== Cell2Fire Local Container Builds ===${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Function to build in a container
build_in_container() {
    local container_image="$1"
    local container_name=$(echo "$container_image" | sed 's/.*://;s/-slim//')
    
    echo -e "${YELLOW}Building with: ${container_image}${NC}"
    
    # Run build in container
    podman run --rm \
        -v "${SCRIPT_DIR}:/workspace:Z" \
        -w /workspace \
        "$container_image" \
        bash -c '
            set -euo pipefail
            
            # Install dependencies
            echo "Installing dependencies..."
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y --no-install-recommends -qq \
                g++ \
                make \
                lsb-release \
                libboost-dev \
                libtiff-dev \
                catch2 \
                > /dev/null
            
            # Get environment info
            DISTRIBUTION=$(lsb_release --short --id 2>/dev/null)
            CODENAME=$(lsb_release --short --codename 2>/dev/null)
            MACHINE=$(uname --machine 2>/dev/null)
            SUFFIX=".${DISTRIBUTION}.${CODENAME}.${MACHINE}"
            
            echo "Building for: ${DISTRIBUTION} ${CODENAME} (${MACHINE})"
            
            # Check Catch2 version
            CATCH2_VERSION=$(dpkg-query -W -f="\${Version}" catch2 2>/dev/null || echo "unknown")
            echo "Catch2 version: ${CATCH2_VERSION}"
            
            # Build
            cd Cell2Fire
            make clean > /dev/null
            make
            
            # Check binary
            echo "Binary info:"
            ldd Cell2Fire
            
            # Copy to output with suffix
            cp Cell2Fire "/workspace/build-output/Cell2Fire${SUFFIX}"
            ldd Cell2Fire > "/workspace/build-output/ldd${SUFFIX}.txt"
            
            echo "Binary saved: Cell2Fire${SUFFIX}"
            
            # Run unit tests
            echo "Running unit tests..."
            make tests
            ./test_cell2fire
            
            echo "Build successful!"
        ' 
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Build successful: ${container_name}${NC}"
    else
        echo -e "${RED}✗ Build failed: ${container_name}${NC}"
        return 1
    fi
    echo ""
}

# Main build loop
failed_builds=()

for container in "${CONTAINERS[@]}"; do
    if ! build_in_container "$container"; then
        failed_builds+=("$container")
    fi
done

# Summary
echo -e "${GREEN}=== Build Summary ===${NC}"
ls -lh "$OUTPUT_DIR"

if [ ${#failed_builds[@]} -eq 0 ]; then
    echo -e "${GREEN}All builds successful!${NC}"
    exit 0
else
    echo -e "${RED}Failed builds:${NC}"
    printf '%s\n' "${failed_builds[@]}"
    exit 1
fi
