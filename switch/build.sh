#!/usr/bin/env bash
# Builds Crazy Taxi 2 for the Switch as a homebrew NRO and stages the SD card's folder:
#
#   out/sd/switch/crazytaxi2/crazytaxi2.nro
#   out/sd/switch/crazytaxi2/crazytaxi2.toml   the game's config with the SD card's paths
#
# The disc (the CHD, into disc/) and 1ST_READ.BIN are game data and are never staged by this
# script: they are copied on Mark's PC from his own dump (tools/win/stage_switch.ps1).
#
# Linux only. Environment:
#   DEVKITPRO   default /opt/devkitpro
#   NVK_SDK     default $DEVKITPRO/portlibs/switch (mesa-switch NVK: lib/libvulkan.a,
#               include/vulkan)
# Both are what ghcr.io/danfromtico/switch-dev-legacy-vulkan (MIT) holds; switch/docker_build.sh
# runs this script inside that image.
#   JOBS        parallel compile jobs (default: by free memory, at most nproc)
#   RELEASE     1 builds a release (CT2_RELEASE: no end-of-run report, no profiler, quick exit);
#               anything else a development build. Only the launcher's own unit changes.
#   PARTS       translation units the game's C++ is split into (default 32: about 176 MB of C++ at about 5.5 MB a unit; CTDC-nx ran out of memory in the cloud at 16 MB a unit)
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
NVK_SDK="${NVK_SDK:-$DEVKITPRO/portlibs/switch}"
PARTS="${PARTS:-32}"
if [ "${RELEASE:-0}" = 1 ]; then RELEASE_FLAG=ON; else RELEASE_FLAG=OFF; fi
HOST="$REPO/out/build-host"
BUILD="$REPO/out/build-switch"
SD="$REPO/out/sd/switch/crazytaxi2"
export WINEDEBUG=-all

fail() { echo "error: $*" >&2; exit 1; }
[ -f "$DEVKITPRO/cmake/Switch.cmake" ] || fail "devkitPro not found at $DEVKITPRO"
[ -f "$NVK_SDK/lib/libvulkan.a" ] || fail "no NVK in $NVK_SDK"
[ -f "$DEVKITPRO/portlibs/switch/include/SDL2/SDL.h" ] || fail "switch-sdl2 missing"
[ -f "$REPO/games/crazytaxi2/extracted/fs/1ST_READ.BIN" ] || fail "the disc is not extracted"

# The dream-recomp patches, as tools/win/common.ps1 applies them: a stamp of the whole set, and
# a clean submodule with every patch applied whenever the set changes.
STAMP="$REPO/out/dream-patches-switch.stamp"
mkdir -p "$REPO/out"
want=$(cat "$REPO"/patches/dream-recomp/*.patch | sha256sum | cut -d' ' -f1)
# A matching stamp is not enough: a submodule reset behind the script's back leaves the stamp
# right and the tree clean (CTDC-nx switch-test8's first build ran on unpatched sources).
if [ "$(cat "$STAMP" 2>/dev/null)" != "$want" ] || git -C "$REPO/dream-recomp" diff --quiet; then
    echo "applying dream-recomp patches ..."
    # ZombieRev-nx: the set is applied to a fresh copy of the pinned sources in out/, and only
    # files whose bytes differ are copied into the submodule. Resetting the submodule in place
    # gave every patched file a new time stamp, so one runtime patch rebuilt all 56 game units
    # (switch-test2: about 60 minutes instead of a few).
    SUB="$REPO/dream-recomp"
    PATCHED="$REPO/out/dream-patched"
    rm -rf "$PATCHED"; mkdir -p "$PATCHED"
    # The commit the superproject pins, not the submodule's HEAD (a local commit there must not
    # become the base).
    PIN=$(git -C "$REPO" rev-parse HEAD:dream-recomp)
    git -C "$SUB" archive "$PIN" | tar -x -C "$PATCHED"
    git -C "$PATCHED" init -q
    for p in "$REPO"/patches/dream-recomp/*.patch; do
        git -C "$PATCHED" apply --whitespace=nowarn "$p" || fail "patch $(basename "$p") does not apply"
    done
    changed=0
    # Files the patched copy has: copy the ones that differ.
    while IFS= read -r -d '' f; do
        rel="${f#$PATCHED/}"
        if ! cmp -s "$f" "$SUB/$rel"; then
            mkdir -p "$(dirname "$SUB/$rel")"; cp -p "$f" "$SUB/$rel"; touch "$SUB/$rel"
            changed=$((changed + 1))
        fi
    done < <(find "$PATCHED" -path "$PATCHED/.git" -prune -o -type f -print0)
    # Files a previous set added (untracked, not ignored) that this set no longer has: remove.
    while IFS= read -r rel; do
        [ -f "$SUB/$rel" ] && [ ! -e "$PATCHED/$rel" ] && { rm -f "$SUB/$rel"; changed=$((changed + 1)); }
    done < <(git -C "$SUB" ls-files --others --exclude-standard)
    # Tracked files the set no longer patches go back to the pin (copied above from the archive).
    echo "  $changed files changed in dream-recomp"
    rm -rf "$PATCHED"
    echo "$want" > "$STAMP"
fi

# The translator runs here, on the build machine, so it is built for it.
if [ ! -x "$HOST/translator/dream-translate" ]; then
    cmake -S "$REPO/dream-recomp" -B "$HOST" -G Ninja -DCMAKE_BUILD_TYPE=Release \
        -DDREAM_BUILD_TESTS=OFF -DDREAM_RENDERER=OFF -DDREAM_WERROR=OFF >/dev/null
fi
ninja -C "$HOST" dream-translate >/dev/null

if [ -z "${JOBS:-}" ]; then
    mem_mb=$(( $(awk '/^MemAvailable:/ {print $2}' /proc/meminfo) / 1024 ))
    JOBS=$(( mem_mb / 2000 )); [ "$JOBS" -lt 1 ] && JOBS=1
    [ "$JOBS" -gt "$(nproc)" ] && JOBS=$(nproc)
fi

cmake -S "$REPO" -B "$BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/Switch.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DDREAM_DEV_INTERPRETER=ON -DDREAM_BUILD_TESTS=OFF -DDREAM_WERROR=OFF \
    -DDREAM_TRANSLATE_PARTS="$PARTS" -DCT2_RELEASE="$RELEASE_FLAG" \
    -DDREAM_HOST_TRANSLATE="$HOST/translator/dream-translate" \
    -DNVK_SDK="$NVK_SDK" >/dev/null
# A launcher built without the renderer stops on the Switch at once (switch-test2): refuse here.
grep -q '^DREAM_GLSLC:FILEPATH=.*NOTFOUND' "$BUILD/CMakeCache.txt" && fail "no glslc: the renderer would be left out"
grep -q '^DREAM_RENDERER:BOOL=ON' "$BUILD/CMakeCache.txt" || fail "the renderer is off"
echo "release build: $RELEASE_FLAG"
ninja -C "$BUILD" -j"$JOBS" crazytaxi2_boot_nro

mkdir -p "$SD"
cp "$BUILD/games/crazytaxi2/crazytaxi2_boot.nro" "$SD/crazytaxi2.nro"
cp "$BUILD/games/crazytaxi2/crazytaxi2_boot.elf" "$REPO/out/crazytaxi2-switch.elf"  # for crash offsets
# The config, pointed at the SD card's layout (relative to sdmc:/switch/crazytaxi2/).
sed -e 's#^image = ".*/\([^/"]*\.\(gdi\|chd\)\)"#image = "disc/\1"#' \
    -e 's#^path = "extracted/fs/1ST_READ.BIN"#path = "1ST_READ.BIN"#' \
    "$REPO/games/crazytaxi2/crazytaxi2.toml" > "$SD/crazytaxi2.toml"
echo
echo "staged $SD/crazytaxi2.nro ($(stat -c %s "$SD/crazytaxi2.nro") bytes)"
sha256sum "$SD/crazytaxi2.nro"
