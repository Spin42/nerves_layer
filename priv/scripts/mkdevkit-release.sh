#!/usr/bin/env bash
#
# Builds the kernel dev kit of a released Nerves system, verifies it against
# the release, and writes it as <out dir>/<system>-<version>.tar.xz.
#
# Usage: mkdevkit-release.sh <system> <version> <work dir> <out dir>
#
# Example: mkdevkit-release.sh nerves_system_rpi5 2.1.2 /tmp/devkit-build out/
#
# Only the kernel is built, from the system's sources at its release tag and
# the nerves_system_br version it pins: same kernel source, config, patches
# and toolchain as the release. Nothing built here is shipped; the dev kit
# is only published if every symbol CRC the release's own modules record
# matches it (verify-devkit.sh).

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -eq 4 ]] || die "usage: mkdevkit-release.sh <system> <version> <work dir> <out dir>"
SYSTEM=$1 VERSION=$2
WORK=$(realpath -m "$3/$SYSTEM-$VERSION")
OUT=$(realpath -m "$4")
REPO="nerves-project/$SYSTEM"

mkdir -p "$WORK" "$OUT"

if [[ ! -d $WORK/system ]]; then
    git clone -q --depth 1 --branch "v$VERSION" "https://github.com/$REPO.git" "$WORK/system"
fi

BR_VERSION=$(sed -n 's/.*{:nerves_system_br, "\([0-9.]*\)".*/\1/p' "$WORK/system/mix.exs")
[[ -n $BR_VERSION ]] || die "$SYSTEM $VERSION doesn't pin an exact nerves_system_br version"
if [[ ! -d $WORK/nerves_system_br ]]; then
    git clone -q --depth 1 --branch "v$BR_VERSION" \
        https://github.com/nerves-project/nerves_system_br.git "$WORK/nerves_system_br"
fi

if [[ ! -f $WORK/output/.config ]]; then
    "$WORK/nerves_system_br/create-build.sh" "$WORK/system/nerves_defconfig" "$WORK/output"
fi
make -C "$WORK/output" linux

DEVKIT_TARBALL="$OUT/$SYSTEM-$VERSION.tar.xz"
"$SCRIPTS/mklinuxdevkit.sh" "$WORK/output" "$DEVKIT_TARBALL.tmp"

# Verify against the published release before publishing anything.
if [[ ! -d $WORK/release ]]; then
    URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/tags/v$VERSION" |
        sed -n 's/.*"browser_download_url": *"\([^"]*\.tar\.gz\)".*/\1/p' | head -1)
    [[ -n $URL ]] || die "no release artifact found for $SYSTEM $VERSION"
    mkdir -p "$WORK/release"
    curl -fsSL "$URL" | tar -x -z -C "$WORK/release" --strip-components=1
fi
mkdir -p "$WORK/verify"
rm -rf "$WORK/verify/linux-devkit"
tar -x -J -f "$DEVKIT_TARBALL.tmp" -C "$WORK/verify"
"$SCRIPTS/verify-devkit.sh" "$WORK/verify/linux-devkit" "$WORK/release"

mv "$DEVKIT_TARBALL.tmp" "$DEVKIT_TARBALL"
echo "$DEVKIT_TARBALL"
