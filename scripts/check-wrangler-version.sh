#!/usr/bin/env bash

set -euo pipefail

required_version=${REQUIRED_WRANGLER_VERSION:-4.135.0}
version_output=$(wrangler --version 2>&1)
installed_version=$(printf '%s\n' "$version_output" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)

if [[ -z "$installed_version" ]]; then
  printf 'Could not determine the installed Wrangler version from: %s\n' "$version_output" >&2
  exit 1
fi

if [[ ! "$required_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid required Wrangler version: %s\n' "$required_version" >&2
  exit 1
fi

IFS=. read -r installed_major installed_minor installed_patch <<< "$installed_version"
IFS=. read -r required_major required_minor required_patch <<< "$required_version"

if (( installed_major < required_major ||
  (installed_major == required_major && installed_minor < required_minor) ||
  (installed_major == required_major && installed_minor == required_minor && installed_patch < required_patch) )); then
  printf 'Wrangler %s is required for Worker Previews; found %s\n' "$required_version" "$installed_version" >&2
  exit 1
fi

printf 'Wrangler %s satisfies the Worker Previews minimum (%s)\n' "$installed_version" "$required_version"
