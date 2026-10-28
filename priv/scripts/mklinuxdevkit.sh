#!/usr/bin/env bash
#
# Package the kernel build products that out-of-tree modules are compiled
# against, from a Nerves system's Buildroot output directory, so modules
# built later match the shipped kernel exactly (vermagic and MODVERSIONS
# CRCs) without rebuilding it.
#
# Usage: mklinuxdevkit.sh <system dir> <output tarball>
#
# <system dir> is a Buildroot output directory with the kernel's build tree
# still in build/, as a locally built Nerves system's artifact directory is.
#
# The file list comes from the kernel's own scripts/package/install-extmod-build,
# the script distributions use for their linux-headers packages. CC and
# HOSTCC are set equal so that it keeps the host programs (fixdep, modpost)
# built for the build machine instead of rebuilding them for the target.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <system dir> <output tarball>" >&2
    exit 1
fi

SYSTEM_DIR=$(realpath "$1")
OUTPUT=$(realpath -m "$2")

LINUX_DIR=
for dir in "$SYSTEM_DIR"/build/linux-*/; do
    if [[ -f "$dir/Module.symvers" ]]; then
        LINUX_DIR=${dir%/}
    fi
done
if [[ -z "$LINUX_DIR" ]]; then
    echo "$0: no kernel build tree (build/linux-*/Module.symvers) in $SYSTEM_DIR" >&2
    exit 1
fi

# "# Linux/arm64 6.18.33 Kernel Configuration"
KERNEL_ARCH=$(sed -n 's|^# Linux/\([^ ]*\) .*|\1|p' "$LINUX_DIR/.config" | head -1)

# Where Buildroot got the kernel: a tarball URL, or a kernel.org version.
SOURCE_URL=$(sed -n 's/^BR2_LINUX_KERNEL_CUSTOM_TARBALL_LOCATION="\(.*\)"$/\1/p' "$SYSTEM_DIR/.config")
if [[ -z "$SOURCE_URL" ]]; then
    VERSION=$(sed -n 's/^BR2_LINUX_KERNEL_VERSION="\(.*\)"$/\1/p' "$SYSTEM_DIR/.config")
    [[ $VERSION =~ ^[0-9]+\.[0-9.]+$ ]] || {
        echo "$0: unsupported kernel source (BR2_LINUX_KERNEL_VERSION=$VERSION)" >&2
        exit 1
    }
    SOURCE_URL="https://cdn.kernel.org/pub/linux/kernel/v${VERSION%%.*}.x/linux-$VERSION.tar.xz"
fi

WORK_DIR=$(mktemp -d)
DEVKIT_DIR="$WORK_DIR/linux-devkit"
trap 'rm -rf "$WORK_DIR"' EXIT

cd "$LINUX_DIR"
if [[ ! -f scripts/package/install-extmod-build ]]; then
    echo "$0: kernel $(cat include/config/kernel.release) has no scripts/package/install-extmod-build" >&2
    exit 1
fi
srctree=. SRCARCH="$KERNEL_ARCH" CC=cc HOSTCC=cc MAKE=make \
    sh scripts/package/install-extmod-build "$DEVKIT_DIR"

cp .config "$DEVKIT_DIR/.config"

# The patches Buildroot applied to the kernel source, in order, so that
# sources fetched later can be patched the same way.
if [[ -s .applied_patches_list ]]; then
    mkdir -p "$DEVKIT_DIR/patches"
    n=0
    while IFS= read -r patch; do
        n=$((n + 1))
        cp "$patch" "$DEVKIT_DIR/patches/$(printf %04d "$n")-$(basename "$patch")"
    done < .applied_patches_list
fi

# Every CONFIG_ option that the source or headers of any compiled object
# reference, as recorded by fixdep in the .cmd files. Enabling one of these
# later would disagree with code that was compiled without it.
find . -name '.*.cmd' -print0 \
    | xargs -0 grep -ho 'include/config/[A-Za-z0-9_]*' \
    | sed 's|include/config/||' \
    | LC_ALL=C sort -u > "$DEVKIT_DIR/kernel-config-refs"

cat > "$DEVKIT_DIR/nerves-devkit.env" <<EOF
NERVES_DEVKIT_VERSION=1
KERNEL_RELEASE=$(cat include/config/kernel.release)
KERNEL_ARCH=$KERNEL_ARCH
KERNEL_SOURCE_URL=$SOURCE_URL
EOF

mkdir -p "$(dirname "$OUTPUT")"
tar -c -J -f "$OUTPUT" -C "$WORK_DIR" \
    --sort=name --owner=0 --group=0 --numeric-owner --mtime=@0 \
    linux-devkit
