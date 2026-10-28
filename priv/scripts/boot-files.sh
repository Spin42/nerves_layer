#!/usr/bin/env bash
#
# Derives a Raspberry Pi fwup.conf that adds device-tree overlays and
# config.txt lines to the boot partition.
#
# Usage: boot-files.sh <fwup.conf> <out dir> [--line <config.txt line>]... [--overlay <name>=<dtbo>]...
#
# Writes <out dir>/fwup.conf, <out dir>/config.txt and <out dir>/overlays/.
# The config.txt file resource points at a config.txt that is the original
# plus the lines. Each overlay gets a file resource and, next to every
# on-resource config.txt block, an on-resource writing it to the same FAT
# partition: the complete install and both A/B upgrade tasks, without
# knowing their layout. Overlays the fwup.conf already ships are left alone.

set -euo pipefail

SCRIPTS=$(dirname "$(realpath "$0")")
source "$SCRIPTS/lib.sh"

[[ $# -ge 2 ]] || die "usage: boot-files.sh <fwup.conf> <out dir> [--line <line>]... [--overlay <name>=<dtbo>]..."
FWUP_CONF=$1 OUT=$2
shift 2

LINES=()
NAMES=()
PATHS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --line) LINES+=("$2") ;;
        --overlay)
            name=${2%%=*}
            if ! grep -q "file-resource overlays/$name.dtbo" "$FWUP_CONF"; then
                NAMES+=("$name")
                PATHS+=("$OUT/overlays/$name.dtbo")
                mkdir -p "$OUT/overlays"
                cp "${2#*=}" "$OUT/overlays/$name.dtbo"
            fi
            ;;
        *) die "unknown argument $1" ;;
    esac
    shift 2
done

# fwup expands ${VAR} and ${VAR:-default}; so does the shell.
RAW=$(sed -n 's/.*file-resource config\.txt *{ *host-path *= *"\([^"]*\)".*/\1/p' "$FWUP_CONF")
[[ -n $RAW ]] || die "$FWUP_CONF has no single-line config.txt file-resource"
ORIGINAL=$(set +u; eval "printf %s \"$RAW\"")

mkdir -p "$OUT"
{
    cat "$ORIGINAL"
    if [[ ${#LINES[@]} -gt 0 ]]; then
        printf '\n# Added by nerves_layer\n'
        printf '%s\n' "${LINES[@]}"
    fi
} > "$OUT/config.txt"

awk -v config_txt="$OUT/config.txt" -v names="${NAMES[*]}" -v paths="${PATHS[*]}" '
BEGIN { n = split(names, name, " "); split(paths, path, " ") }

/^[[:space:]]*file-resource config\.txt[[:space:]]*\{/ {
    print "file-resource config.txt { host-path = \"" config_txt "\" }"
    for (i = 1; i <= n; i++)
        print "file-resource overlays/" name[i] ".dtbo { host-path = \"" path[i] "\" }"
    next
}

/^[[:space:]]*on-resource config\.txt[[:space:]]*\{/ {
    in_block = 1; depth = 0; partition = ""
    indent = $0; sub(/on-resource.*/, "", indent)
}

in_block {
    print
    depth += gsub(/\{/, "{") - gsub(/\}/, "}")
    if (match($0, /fat_write\(\$\{[A-Za-z0-9_]+\}, *"config\.txt"\)/)) {
        partition = substr($0, RSTART + 12)
        sub(/\}.*/, "", partition)
    }
    if (depth == 0) {
        in_block = 0
        if (partition == "") { print "no fat_write of config.txt in a config.txt block" > "/dev/stderr"; exit 1 }
        for (i = 1; i <= n; i++)
            print indent "on-resource overlays/" name[i] ".dtbo { fat_write(${" partition "}, \"overlays/" name[i] ".dtbo\") }"
        blocks++
    }
    next
}

{ print }

END { if (n > 0 && blocks == 0) { print "no on-resource config.txt blocks found" > "/dev/stderr"; exit 1 } }
' "$FWUP_CONF" > "$OUT/fwup.conf"

echo "$OUT/fwup.conf"
