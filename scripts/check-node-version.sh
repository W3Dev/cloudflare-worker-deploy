#!/usr/bin/env bash

set -euo pipefail

required_major=${REQUIRED_NODE_MAJOR:-22}
node_version=$(node --version 2>&1)
installed_major=$(printf '%s\n' "$node_version" | grep -Eo '^v?[0-9]+' | head -n 1 | tr -d 'v' || true)

if [[ -z "$installed_major" ]]; then
  printf 'Could not determine the installed Node.js version from: %s\n' "$node_version" >&2
  exit 1
fi

if [[ ! "$required_major" =~ ^[0-9]+$ ]]; then
  printf 'Invalid required Node.js major version: %s\n' "$required_major" >&2
  exit 1
fi

if (( installed_major < required_major )); then
  printf 'Node.js %s or newer is required for Worker Previews; found %s\n' "$required_major" "$node_version" >&2
  exit 1
fi

printf 'Node.js %s satisfies the Worker Previews minimum (%s)\n' "$node_version" "$required_major"
