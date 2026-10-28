#!/usr/bin/env bash
#
# Checks that a kernel dev kit matches the kernel a Nerves system ships.
#
# Usage: verify-devkit.sh <devkit> <system dir>
#
# Every module the system ships records the CRC of each kernel symbol it
# uses. They must all appear, with the same CRC, in the dev kit's
# Module.symvers, and the modules' kernel release must be the dev kit's.
# Modules built against a dev kit that passes are accepted by the kernel.

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -eq 2 ]] || die "usage: verify-devkit.sh <devkit> <system dir>"
DEVKIT=$1
SYSTEM_DIR=$2
RELEASE=$(devkit_env "$DEVKIT" KERNEL_RELEASE)

grep -qx CONFIG_MODVERSIONS=y "$DEVKIT/.config" ||
    die "kernel $RELEASE is built without CONFIG_MODVERSIONS: its modules record no symbol CRCs to verify the dev kit against"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

if [[ -f $SYSTEM_DIR/images/rootfs.tar ]]; then
    tar -x -f "$SYSTEM_DIR/images/rootfs.tar" -C "$WORK" --wildcards '*lib/modules/*'
else
    unsquashfs -q -f -d "$WORK" "$SYSTEM_DIR/images/rootfs.squashfs" /lib/modules > /dev/null
fi

MODULES_DIR=$(find "$WORK" -type d -path '*/lib/modules/*' -prune | head -1)
[[ -n $MODULES_DIR ]] || die "the system ships no kernel modules to verify the dev kit against"
[[ $(basename "$MODULES_DIR") == "$RELEASE" ]] ||
    die "dev kit is for kernel $RELEASE but the system ships $(basename "$MODULES_DIR")"

# "<crc> <symbol>" pairs, as the system's modules and the dev kit see them.
find "$MODULES_DIR" -name '*.ko*' -print0 |
    xargs -0 -n 1 modprobe --dump-modversions |
    awk '{print $1, $2}' | LC_ALL=C sort -u > "$WORK/used"
awk '{print $1, $2}' "$DEVKIT/Module.symvers" | LC_ALL=C sort -u > "$WORK/provided"

MISMATCHES=$(LC_ALL=C comm -23 "$WORK/used" "$WORK/provided")
if [[ -n $MISMATCHES ]]; then
    echo "$MISMATCHES" | head -10 >&2
    die "dev kit doesn't match the system's kernel: $(echo "$MISMATCHES" | wc -l) symbol CRC(s) differ"
fi

echo "nerves_layer: dev kit matches $RELEASE ($(wc -l < "$WORK/used") symbol CRCs checked)" >&2
