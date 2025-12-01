#!/usr/bin/env bash
# Quick interactive container build script

CONTAINERS=(
    "debian:bookworm-slim"
    "debian:trixie-slim"
    "ubuntu:22.04"
    "ubuntu:24.04"
)

echo "Select container to build with:"
select container in "${CONTAINERS[@]}" "All" "Quit"; do
    case $container in
        "Quit")
            exit 0
            ;;
        "All")
            exec ./build-local-containers.sh
            ;;
        *)
            if [ -n "$container" ]; then
                echo "Building with: $container"
                podman run --rm -it \
                    -v "$(pwd):/workspace:Z" \
                    -w /workspace \
                    "$container" \
                    bash
                break
            fi
            ;;
    esac
done
