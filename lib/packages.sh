#!/bin/bash
# lib/packages.sh — Package list builder from profile files
# Source this file; do not execute directly.

PACKAGES_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
PROFILES_DIR="${PACKAGES_SCRIPT_DIR}/../profiles"

# ---------------------------------------------------------------------------
# build_package_list
# Reads the PROFILES variable (space-separated profile names), concatenates
# the corresponding profiles/*.txt files, deduplicates, and prints the result
# as a single space-separated string suitable for pacstrap / pacman.
# ---------------------------------------------------------------------------
build_package_list() {
    local packages=()
    local profile profile_file pkg

    for profile in $PROFILES; do
        profile_file="${PROFILES_DIR}/${profile}.txt"
        if [[ ! -f "$profile_file" ]]; then
            log_warn "Profile '${profile}' not found at ${profile_file}, skipping."
            continue
        fi
        while IFS= read -r pkg || [[ -n "$pkg" ]]; do
            # Skip blank lines and comments
            [[ -z "$pkg" || "$pkg" =~ ^[[:space:]]*# ]] && continue
            packages+=("$pkg")
        done < "$profile_file"
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages found for PROFILES='${PROFILES}'. Check your profile files."
        return 1
    fi

    # Deduplicate while preserving a deterministic order
    printf '%s\n' "${packages[@]}" | sort -u | tr '\n' ' '
}
