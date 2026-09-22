#!/usr/bin/env bash

set -Eeuo pipefail

account_id=${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}
api_token=${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}
worker_name=${WORKER_NAME:?WORKER_NAME is required}
output_path=${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}

if [[ ! "$account_id" =~ ^[[:xdigit:]]{32}$ ]]; then
  printf 'CLOUDFLARE_ACCOUNT_ID must be a 32-character hexadecimal ID\n' >&2
  exit 1
fi
if [[ ! "$worker_name" =~ ^w3dev-live-preview-[0-9]+-[0-9]+$ ]]; then
  printf 'Unexpected live smoke Worker name format\n' >&2
  exit 1
fi

endpoint="https://api.cloudflare.com/client/v4/accounts/$account_id/workers/workers/$worker_name"
response_file=$(mktemp)
trap 'rm -f -- "$response_file"' EXIT

status=$(curl \
  --silent \
  --show-error \
  --output "$response_file" \
  --write-out '%{http_code}' \
  --connect-timeout 10 \
  --max-time 30 \
  --header "Authorization: Bearer $api_token" \
  "$endpoint")

case "$status" in
  404)
    printf 'parent_worker_absent=true\n' >> "$output_path"
    printf 'Preflight confirmed that the dedicated Worker does not exist.\n'
    ;;
  200)
    printf 'The dedicated Worker already exists; refusing to run the smoke test.\n' >&2
    exit 1
    ;;
  *)
    printf 'Unexpected parent Worker preflight response: HTTP %s\n' "$status" >&2
    exit 1
    ;;
esac
