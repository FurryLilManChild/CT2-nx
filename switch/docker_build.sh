#!/usr/bin/env bash
# Runs switch/build.sh inside ghcr.io/danfromtico/switch-dev-legacy-vulkan (MIT): devkitPro's
# Linux toolchain (devkitA64, libnx, switch-sdl2) plus mesa-switch's NVK. Mark OK'd pulling it
# for the cloud Switch builds (2026-11-03). The repository is mounted at the same path inside.
#
# The image has no glslc (the build machine's shader compiler). Without it CMake quietly builds
# the launcher with no renderer, which on the Switch stops at once with "this build has no
# renderer" (switch-test2). So a local image adds Debian's glslc on top, once.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="${BASE:-ghcr.io/danfromtico/switch-dev-legacy-vulkan:latest}"
IMAGE=ctdc-nx/switch-dev:glslc

# The cloud machine does not keep the docker daemon running between sessions.
if ! docker info >/dev/null 2>&1; then
    (dockerd >/tmp/dockerd.log 2>&1 &)
    for _ in $(seq 60); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker rm -f ctdc-glslc >/dev/null 2>&1 || true
    docker run --name ctdc-glslc "$BASE" bash -c 'apt-get update >/dev/null 2>&1; apt-get install -y glslc >/dev/null && glslc --version | head -1'
    docker commit ctdc-glslc "$IMAGE" >/dev/null
    docker rm ctdc-glslc >/dev/null
fi
exec docker run --rm -v "$REPO:$REPO" -w "$REPO" -e JOBS -e PARTS -e RELEASE "$IMAGE" \
    bash -c "git config --global --add safe.directory '*' && bash switch/build.sh"
