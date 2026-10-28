#!/usr/bin/env bash
#
# Checks that a kernel config fragment only adds modules, and prints the
# options it changes as CONFIG_<NAME>=<value> lines.
#
# Usage: check-config.sh <system .config> <base .config> <resolved .config> <config refs> <kernel tree>
#
# <base> and <resolved> are the system's config run through Kconfig without
# and with the fragment, so that options Kconfig derives from the toolchain
# cancel out. Every option that differs must:
#
#   * have been unset in the system, which a layer can't contradict
#   * not be in <config refs>, the options compiled system code references
#     (CONFIG_CAN, for example, changes struct net)
#   * if it became y, not build objects into the kernel image
#     (obj-$(CONFIG_<NAME>) in a makefile)

set -euo pipefail

[[ $# -eq 5 ]] || { echo "usage: check-config.sh <system> <base> <resolved> <refs> <tree>" >&2; exit 1; }
SYSTEM=$1 BASE=$2 RESOLVED=$3 REFS=$4 TREE=$5

values() { grep -E '^CONFIG_[A-Za-z0-9_]+=' "$1" | LC_ALL=C sort; }

PROBLEMS=()

# Options Kconfig turned off.
while IFS= read -r line; do
    name=${line%%=*}
    grep -q "^$name=" "$RESOLVED" || PROBLEMS+=("  $name: the fragment would disable it")
done < <(LC_ALL=C comm -23 <(values "$BASE") <(values "$RESOLVED"))

# Options Kconfig turned on or changed.
CHANGES=$(LC_ALL=C comm -13 <(values "$BASE") <(values "$RESOLVED"))
while IFS= read -r line; do
    [[ -n $line ]] || continue
    name=${line%%=*}
    value=${line#*=}
    old=$(sed -n "s/^$name=//p" "$SYSTEM")

    if [[ -n $old ]]; then
        PROBLEMS+=("  $name: the system sets it to $old; a layer can't change it to $value")
    elif grep -qx "${name#CONFIG_}" "$REFS"; then
        PROBLEMS+=("  $name: code compiled into the system references it, so it has to be enabled in the system itself")
    elif [[ $value == y ]] && grep -rqF --include=Makefile --include=Kbuild "obj-\$($name)" "$TREE"; then
        PROBLEMS+=("  $name=y would build code into the kernel image; only modules (=m) can be added")
    fi
done <<< "$CHANGES"

if [[ ${#PROBLEMS[@]} -gt 0 ]]; then
    echo "The kernel config fragment can't be built as modules for this system:" >&2
    printf '%s\n' "${PROBLEMS[@]}" >&2
    exit 1
fi

echo "$CHANGES"
