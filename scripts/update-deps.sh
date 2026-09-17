#!/usr/bin/env bash
#
# Vendors the CET kit modules listed in deps.lock.
#
# The modules live in the repo so that a plain "Download ZIP" gives a working
# mod folder. deps.lock pins the upstream commit and a checksum per file so the
# vendored copies stay verifiable instead of quietly drifting.
#
#   ./scripts/update-deps.sh            fetch the pinned commit and install it
#   ./scripts/update-deps.sh --check    verify the working tree matches the lock
#   ./scripts/update-deps.sh --upgrade  move the pin to upstream HEAD, rewrite lock
#
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lock_file="${repo_root}/deps.lock"

REPO=""
COMMIT=""
BRANCH="main"
SRCS=()
DESTS=()
HASHES=()

# One scratch dir for the whole run. Declared up front so the EXIT trap can see
# it; a trap set inside a function outlives that function's locals.
work_dir=""

cleanup() {
    if [ -n "$work_dir" ]; then
        rm -rf "$work_dir"
    fi
}
trap cleanup EXIT

die() {
    echo "error: $*" >&2
    exit 1
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d' ' -f1
    else
        die "neither sha256sum nor shasum found"
    fi
}

read_lock() {
    [ -f "$lock_file" ] || die "$lock_file not found"

    local key a b c
    while read -r key a b c; do
        case "$key" in
            ''|'#'*) continue ;;
            repo)    REPO="$a" ;;
            branch)  BRANCH="$a" ;;
            commit)  COMMIT="$a" ;;
            file)    SRCS+=("$a"); DESTS+=("$b"); HASHES+=("$c") ;;
            *)       die "unrecognised key '$key' in deps.lock" ;;
        esac
    done < "$lock_file"

    [ -n "$REPO" ]   || die "deps.lock is missing a 'repo' entry"
    [ -n "$COMMIT" ] || die "deps.lock is missing a 'commit' entry"
    [ ${#SRCS[@]} -gt 0 ] || die "deps.lock lists no files"
}

write_lock() {
    local commit="$1"; shift
    {
        echo "# Vendored dependencies. Managed by scripts/update-deps.sh -- do not hand-edit"
        echo "# the files under cet-kit/; CI verifies them against the checksums below."
        echo
        echo "repo	${REPO}"
        echo "branch	${BRANCH}"
        echo "commit	${commit}"
        echo
        local i
        for i in "${!SRCS[@]}"; do
            echo "file	${SRCS[$i]}	${DESTS[$i]}	$1"
            shift
        done
    } > "$lock_file"
}

fetch() {
    local commit="$1" src="$2" out="$3"
    local url="https://raw.githubusercontent.com/${REPO}/${commit}/${src}"

    curl -fsSL "$url" -o "$out" || die "failed to download $url"
    [ -s "$out" ] || die "downloaded $src is empty"
}

resolve_head() {
    local line
    line="$(git ls-remote "https://github.com/${REPO}.git" "refs/heads/${BRANCH}")" \
        || die "could not reach https://github.com/${REPO}.git"
    [ -n "$line" ] || die "branch '${BRANCH}' not found in ${REPO}"
    echo "$line" | cut -f1
}

cmd_sync() {
    local i failed=0
    work_dir="$(mktemp -d)"

    echo "Fetching ${REPO} at ${COMMIT:0:12}"

    for i in "${!SRCS[@]}"; do
        local staged
        staged="${work_dir}/$(basename "${SRCS[$i]}")"
        fetch "$COMMIT" "${SRCS[$i]}" "$staged"

        local got
        got="$(sha256_of "$staged")"
        if [ "$got" != "${HASHES[$i]}" ]; then
            echo "  ${SRCS[$i]}: CHECKSUM MISMATCH" >&2
            echo "    expected ${HASHES[$i]}" >&2
            echo "    actual   ${got}" >&2
            failed=1
            continue
        fi

        mkdir -p "$(dirname "${repo_root}/${DESTS[$i]}")"
        cp "$staged" "${repo_root}/${DESTS[$i]}"
        echo "  ${DESTS[$i]}: ok"
    done

    [ "$failed" -eq 0 ] || die "one or more downloads did not match deps.lock"
}

cmd_check() {
    local i failed=0

    for i in "${!SRCS[@]}"; do
        local path="${repo_root}/${DESTS[$i]}"

        if [ ! -f "$path" ]; then
            echo "  ${DESTS[$i]}: MISSING" >&2
            failed=1
            continue
        fi

        local got
        got="$(sha256_of "$path")"
        if [ "$got" != "${HASHES[$i]}" ]; then
            echo "  ${DESTS[$i]}: MODIFIED" >&2
            echo "    expected ${HASHES[$i]}" >&2
            echo "    actual   ${got}" >&2
            failed=1
        else
            echo "  ${DESTS[$i]}: ok"
        fi
    done

    if [ "$failed" -ne 0 ]; then
        die "vendored files do not match deps.lock. Do not edit cet-kit/ by hand:
       send the fix upstream to ${REPO}, then run scripts/update-deps.sh --upgrade."
    fi

    echo "Vendored files match deps.lock (${REPO} at ${COMMIT:0:12})"
}

cmd_upgrade() {
    local head i
    head="$(resolve_head)"

    if [ "$head" = "$COMMIT" ]; then
        echo "Already pinned to ${BRANCH} HEAD (${COMMIT:0:12}); nothing to do."
        return 0
    fi

    echo "Upgrading ${REPO}: ${COMMIT:0:12} -> ${head:0:12}"

    work_dir="$(mktemp -d)"

    local new_hashes=()
    for i in "${!SRCS[@]}"; do
        local staged
        staged="${work_dir}/$(basename "${SRCS[$i]}")"
        fetch "$head" "${SRCS[$i]}" "$staged"
        new_hashes+=("$(sha256_of "$staged")")

        mkdir -p "$(dirname "${repo_root}/${DESTS[$i]}")"
        cp "$staged" "${repo_root}/${DESTS[$i]}"
        echo "  ${DESTS[$i]}: updated"
    done

    write_lock "$head" "${new_hashes[@]}"
    echo "deps.lock rewritten."
}

main() {
    read_lock

    case "${1:---sync}" in
        --sync)    cmd_sync ;;
        --check)   cmd_check ;;
        --upgrade) cmd_upgrade ;;
        -h|--help) awk 'NR > 1 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}" ;;
        *)         die "unknown option '$1' (expected --sync, --check or --upgrade)" ;;
    esac
}

main "$@"
