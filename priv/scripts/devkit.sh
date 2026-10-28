#!/usr/bin/env bash
#
# Prints the path of the active Nerves system's kernel dev kit, extracted
# under <work dir> and verified against the system's kernel.
#
# Usage: devkit.sh <system dir> <work dir>
#
# The dev kit comes from, in order:
#
#   1. the system itself, as images/linux-devkit.tar.xz
#   2. the system's kernel build tree, which locally built systems keep
#   3. a dev kit artifact pinned to the system release,
#      <devkits dir>/<system>-<version>.tar.xz, downloaded from
#      <devkit url>/<system>-<version>.tar.xz if it's missing
#
# <devkits dir> is $NERVES_LAYER_DEVKITS_DIR, defaulting to
# nerves_layer/devkits in the Nerves data directory. <devkit url> is
# $NERVES_LAYER_DEVKIT_URL, defaulting to the "devkits" release of the
# nerves_layer repository; set it to an empty string to never download.

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -eq 2 ]] || die "usage: devkit.sh <system dir> <work dir>"
SYSTEM_DIR=$1
WORK_DIR=$2

# Nerves names system artifact directories <system>-<host tuple>-<version>.
SYSTEM_NAME=$(basename "$SYSTEM_DIR")
ARTIFACT_NAME="${SYSTEM_NAME%%-portable-*}-${SYSTEM_NAME##*-portable-}"
DEVKITS_DIR=${NERVES_LAYER_DEVKITS_DIR:-${NERVES_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/nerves}/nerves_layer/devkits}
DEVKIT_URL=${NERVES_LAYER_DEVKIT_URL-https://github.com/spin42/nerves_layer/releases/download/devkits}
SYMVERS=$(ls "$SYSTEM_DIR"/build/linux-*/Module.symvers 2>/dev/null | head -1 || true)

if [[ -f $SYSTEM_DIR/images/linux-devkit.tar.xz ]]; then
    TARBALL="$SYSTEM_DIR/images/linux-devkit.tar.xz"
elif [[ -n $SYMVERS ]]; then
    TARBALL="$WORK_DIR/linux-devkit.tar.xz"
    if [[ ! -f $TARBALL || $SYMVERS -nt $TARBALL ]]; then
        echo "nerves_layer: generating the kernel dev kit from $(dirname "$SYMVERS")" >&2
        "$SCRIPTS/mklinuxdevkit.sh" "$SYSTEM_DIR" "$TARBALL"
    fi
else
    TARBALL="$DEVKITS_DIR/$ARTIFACT_NAME.tar.xz"
    if [[ ! -f $TARBALL ]]; then
        [[ -n $DEVKIT_URL ]] ||
            die "no kernel dev kit for $ARTIFACT_NAME: the system ships none, has no kernel build tree, and $TARBALL doesn't exist"
        echo "nerves_layer: downloading the $ARTIFACT_NAME kernel dev kit from $DEVKIT_URL" >&2
        mkdir -p "$DEVKITS_DIR"
        if ! curl -fsSL -o "$TARBALL.tmp" "$DEVKIT_URL/$ARTIFACT_NAME.tar.xz"; then
            rm -f "$TARBALL.tmp"
            die "no kernel dev kit for $ARTIFACT_NAME at $DEVKIT_URL; see devkits.txt in the nerves_layer repository for the systems with published dev kits"
        fi
        mv "$TARBALL.tmp" "$TARBALL"
    fi
fi

DIGEST=$(sha256sum "$TARBALL" | cut -c1-16)
ROOT="$WORK_DIR/devkit-$DIGEST"
DEVKIT="$ROOT/linux-devkit"
if [[ ! -f $ROOT/verified ]]; then
    rm -rf "$ROOT"
    mkdir -p "$ROOT"
    tar -x -J -f "$TARBALL" -C "$ROOT"
    "$SCRIPTS/verify-devkit.sh" "$DEVKIT" "$SYSTEM_DIR"
    touch "$ROOT/verified"
fi
echo "$DEVKIT"
