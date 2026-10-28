#!/usr/bin/env bash
#
# Compiles device-tree overlay sources the way the kernel compiles its own:
# the C preprocessor with the kernel's headers (for <dt-bindings/...>), then
# the kernel's own dtc with -@ so the bootloader can resolve references.
#
# Usage: build-overlays.sh <devkit> <out dir> <source>...
#
# Environment: CROSS_COMPILE, NERVES_LAYER_SOURCE_CACHE (kernel checkouts,
# where dtc is built once next to the checkout).

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -ge 3 ]] || die "usage: build-overlays.sh <devkit> <out dir> <source>..."
DEVKIT=$1 OUT=$2
shift 2

SRC=$(kernel_checkout "$DEVKIT" "$NERVES_LAYER_SOURCE_CACHE")
DTC_BUILD="$SRC-dtc"
DTC="$DTC_BUILD/scripts/dtc/dtc"

if [[ ! -x $DTC ]]; then
    echo "nerves_layer: building the kernel's dtc" >&2
    rm -rf "$DTC_BUILD"
    mkdir -p "$DTC_BUILD"
    cp "$DEVKIT/.config" "$DTC_BUILD/.config"
    make -s -C "$SRC" O="$DTC_BUILD" ARCH="$(devkit_env "$DEVKIT" KERNEL_ARCH)" \
        CROSS_COMPILE="$CROSS_COMPILE" olddefconfig scripts_dtc
fi

mkdir -p "$OUT"
for source in "$@"; do
    name=$(basename "${source%.*}")
    echo "    DTC $(basename "$source")" >&2
    cc -E -nostdinc -I "$DEVKIT/include" -I "$(dirname "$source")" -undef -D__DTS__ \
        -x assembler-with-cpp -o "$OUT/$name.pre.dts" "$source"
    # The kernel's default DTC_FLAGS (scripts/Makefile.dtbs).
    "$DTC" -@ -H epapr -I dts -O dtb -b 0 -i "$(dirname "$source")" \
        -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size \
        -Wno-alias_paths -Wno-graph_child_address -Wno-interrupt_map -Wno-simple_bus_reg \
        -o "$OUT/$name.dtbo" "$OUT/$name.pre.dts"
    rm "$OUT/$name.pre.dts"
done
