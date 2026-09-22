#!/usr/bin/env bash

set -Eeuo pipefail

fixture_dir=${1:?fixture directory is required}
worker_name=${2:?Worker name is required}

if [[ ! "$worker_name" =~ ^w3dev-live-preview-[0-9]+-[0-9]+$ ]]; then
  printf 'Unexpected live smoke Worker name format\n' >&2
  exit 1
fi

cat > "$fixture_dir/wrangler.jsonc" <<JSON
{
  "\$schema": "https://unpkg.com/wrangler@4.135.0/config-schema.json",
  "name": "$worker_name",
  "main": "src/index.js",
  "compatibility_date": "2026-09-22",
  "workers_dev": true,
  "preview_urls": true,
  "previews": {}
}
JSON
