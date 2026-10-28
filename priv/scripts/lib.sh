# Helpers shared by the nerves_layer scripts. Source it; don't run it.

die() {
    echo "nerves_layer: $*" >&2
    exit 1
}

# devkit_env <devkit> <key>
devkit_env() {
    sed -n "s/^$2=//p" "$1/nerves-devkit.env"
}

# kernel_git <tarball url>
#
# Prints "<git repository> <ref>" for the kernel source tarball Buildroot
# downloaded: a GitHub archive, a kernel.org stable release, or another cgit
# snapshot. kernel.org stable releases are fetched from the GitHub mirror of
# the stable tree, since git.kernel.org doesn't serve partial clones.
kernel_git() {
    local url=$1
    local github='^https://github\.com/([^/]+)/([^/]+)/archive/(refs/(tags|heads)/)?(.+)\.tar\.(gz|xz|bz2)$'
    local kernel_org='^https://(cdn\.kernel\.org/pub/linux/kernel/v[0-9]+\.x|git\.kernel\.org/pub/scm/linux/kernel/git/stable/linux\.git/snapshot)/linux-([0-9.]+)\.tar\.(gz|xz)$'
    local cgit='^(https?://.+)/snapshot/(.+)\.tar\.(gz|xz|bz2)$'

    if [[ $url =~ $github ]]; then
        echo "https://github.com/${BASH_REMATCH[1]}/${BASH_REMATCH[2]}.git ${BASH_REMATCH[5]}"
    elif [[ $url =~ $kernel_org ]]; then
        echo "https://github.com/gregkh/linux.git v${BASH_REMATCH[2]}"
    elif [[ $url =~ $cgit ]]; then
        # cgit names snapshots <repo>-<ref>, dropping a tag's leading "v".
        local repo=${BASH_REMATCH[1]} name=${BASH_REMATCH[2]}
        local ref=${name#"$(basename "${repo%.git}")"-}
        if git ls-remote --exit-code -q "$repo" "refs/tags/v$ref" > /dev/null 2>&1; then
            ref="v$ref"
        fi
        echo "$repo $ref"
    else
        die "can't fetch kernel sources selectively from $url"
    fi
}

# kernel_checkout <devkit> <cache root>
#
# Prints the path of a sparse, partial git checkout of the dev kit's kernel
# source, with Kconfig files, makefiles and scripts/ checked out and the dev
# kit's kernel patches applied. Only the tree structure is downloaded up
# front; file contents are fetched for what is checked out. Checkouts are
# cached per source and patch set.
kernel_checkout() {
    local devkit=$1 url arch repo ref dir patches=()
    url=$(devkit_env "$devkit" KERNEL_SOURCE_URL)
    arch=$(devkit_env "$devkit" KERNEL_ARCH)
    if [[ -d $devkit/patches ]]; then
        patches=("$devkit"/patches/*)
    fi

    dir="$2/$( (printf %s "$url"; cat "${patches[@]}" < /dev/null) | sha256sum | cut -c1-16)"
    if [[ ! -f $dir/.git/nerves_layer_ready ]]; then
        read -r repo ref <<< "$(kernel_git "$url")"
        echo "nerves_layer: fetching kernel sources ($ref) from $repo" >&2
        rm -rf "$dir"
        mkdir -p "$dir"
        git -C "$dir" init -q
        git -C "$dir" remote add origin "$repo"
        git -C "$dir" fetch -q --depth 1 --filter=blob:none origin "$ref"
        git -C "$dir" sparse-checkout set --no-cone \
            /Makefile /Kbuild /scripts/ 'Kconfig*' Makefile Kbuild "/arch/$arch/Makefile"
        git -C "$dir" checkout -q FETCH_HEAD

        if [[ ${#patches[@]} -gt 0 ]]; then
            # Check out what the patches touch, apply them as Buildroot did,
            # and commit, so that later checkouts see the patched tree.
            local path touched=()
            while read -r path; do
                kernel_has "$dir" "$path" && touched+=("$path")
            done < <(sed -n 's|^--- a/\([^[:space:]]*\).*|\1|p' "${patches[@]}" | sort -u)
            kernel_add "$dir" "${touched[@]}"
            for patch in "${patches[@]}"; do
                patch -s -p1 -d "$dir" < "$patch"
            done
            git -C "$dir" add --sparse -A
            git -C "$dir" -c user.name=nerves_layer -c user.email=nerves_layer@localhost \
                commit -q -m "Kernel patches from the dev kit"
        fi
        touch "$dir/.git/nerves_layer_ready"
    fi
    echo "$dir"
}

# kernel_add <checkout> <tree path>...
#
# Checks out more files, fetching their contents.
kernel_add() {
    local dir=$1 path missing=()
    shift
    for path in "$@"; do
        [[ -e $dir/$path ]] || missing+=("/$path")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        git -C "$dir" sparse-checkout add "${missing[@]}"
    fi
}

# kernel_has <checkout> <tree path>
#
# Whether the path exists in the kernel tree, checked out or not.
kernel_has() {
    git -C "$1" cat-file -e "HEAD:$2" 2>/dev/null
}
