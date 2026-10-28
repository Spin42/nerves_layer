#!/usr/bin/env bash
#
# Checks that a built hello_layer .fw contains everything its layers add at
# firmware build time, without booting it.
#
# Usage: scripts/verify-firmware.sh [path/to/hello_layer.fw]

set -euo pipefail

FW=${1:-_build/rpi4_dev/nerves/images/hello_layer.fw}
LAYER=nerves_layer_hifiberry_dacplus
OVERLAY=hifiberry-dacplus
MODULES=(snd-soc-pcm512x snd-soc-pcm512x-i2c snd-soc-tpa6130a2 snd-soc-hifiberry-dacplus clk-hifiberry-dacpro)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

failures=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; failures=$((failures + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

echo "Firmware: $FW"

echo "Boot partition"
check "overlays/$OVERLAY.dtbo is a firmware resource" \
    "unzip -l '$FW' | grep -q 'data/overlays/$OVERLAY.dtbo'"
check "config.txt enables the overlay" \
    "unzip -p '$FW' data/config.txt | grep -qx 'dtoverlay=$OVERLAY'"

unzip -p "$FW" meta.conf > "$WORK/meta.conf"
config_writes=$(grep -c 'on-resource "config.txt"' "$WORK/meta.conf" || true)
overlay_writes=$(grep -c "on-resource \"overlays/$OVERLAY.dtbo\"" "$WORK/meta.conf" || true)
check "overlay written by every task that writes config.txt ($overlay_writes/$config_writes)" \
    "[[ $config_writes -gt 0 && $overlay_writes -eq $config_writes ]]"

hello_writes=$(grep -c 'on-resource "overlays/hello-led.dtbo"' "$WORK/meta.conf" || true)
check "hello-led overlay, compiled from source, written by every such task ($hello_writes/$config_writes)" \
    "[[ $hello_writes -eq $config_writes ]]"
check "config.txt enables hello-led" \
    "unzip -p '$FW' data/config.txt | grep -qx 'dtoverlay=hello-led'"

echo "Root filesystem"
unzip -p "$FW" data/rootfs.img > "$WORK/rootfs.img"
unsquashfs -q -d "$WORK/root" "$WORK/rootfs.img" lib/modules > /dev/null
release=$(ls "$WORK/root/lib/modules")
moddir="$WORK/root/lib/modules/$release"
echo "  kernel release $release"

for m in "${MODULES[@]}"; do
    check "updates/$LAYER/$m.ko installed" "[[ -f '$moddir/updates/$LAYER/$m.ko' ]]"
    check "$m indexed in modules.dep" "grep -q '^updates/$LAYER/$m.ko:' '$moddir/modules.dep'"
done

check "machine driver autoloads from the device tree (modules.alias)" \
    "grep -q 'snd_soc_hifiberry_dacplus' '$moddir/modules.alias'"
check "layer module depends on layer module (pcm512x-i2c -> pcm512x)" \
    "grep '^updates/$LAYER/snd-soc-pcm512x-i2c.ko:' '$moddir/modules.dep' | grep -q 'updates/$LAYER/snd-soc-pcm512x.ko'"
check "layer module depends on system module (tpa6130a2 -> regmap-i2c)" \
    "grep '^updates/$LAYER/snd-soc-tpa6130a2.ko:' '$moddir/modules.dep' | grep -q 'kernel/drivers/base/regmap/regmap-i2c.ko'"
check "system modules still indexed" \
    "grep -q '^kernel/sound/soc/snd-soc-core.ko' '$moddir/modules.dep'"

echo "Binaries"
unsquashfs -q -d "$WORK/srv" "$WORK/rootfs.img" srv/erlang/lib > /dev/null
check "flac from nbpr_flac in the release" \
    "compgen -G '$WORK/srv/srv/erlang/lib/nbpr_flac-*/priv/usr/bin/flac' > /dev/null"

if [[ $failures -gt 0 ]]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "All checks passed"
