#!/usr/bin/env bash
#
# Builds the out-of-tree modules described by <kbuild dir>/Kbuild against a
# dev kit, and collects them, stripped of debug info, into <out dir>.
#
# Usage: build-modules.sh <devkit> <kbuild dir> <out dir> [make argument...]
#
# Environment: CROSS_COMPILE

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -ge 3 ]] || die "usage: build-modules.sh <devkit> <kbuild dir> <out dir> [make argument...]"
DEVKIT=$1 KBUILD_DIR=$2 OUT=$3
shift 3

make -C "$DEVKIT" M="$KBUILD_DIR" ARCH="$(devkit_env "$DEVKIT" KERNEL_ARCH)" \
    CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)" "$@" modules

mkdir -p "$OUT"
find "$KBUILD_DIR" -name '*.ko' -print0 | while IFS= read -r -d '' ko; do
    cp "$ko" "$OUT/"
    "${CROSS_COMPILE}strip" --strip-debug "$OUT/$(basename "$ko")"
done
