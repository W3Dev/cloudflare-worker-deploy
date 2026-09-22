#!/usr/bin/env bash

set -Eeuo pipefail

account_id=${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID is required}
api_token=${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required}
worker_name=${WORKER_NAME:?WORKER_NAME is required}
preview_name=${PREVIEW_NAME:?PREVIEW_NAME is required}

if [[ ! "$account_id" =~ ^[[:xdigit:]]{32}$ ]]; then
  printf 'CLOUDFLARE_ACCOUNT_ID must be a 32-character hexadecimal ID\n' >&2
  exit 1
fi
if [[ ! "$worker_name" =~ ^w3dev-live-preview-[0-9]+-[0-9]+$ ]]; then
  printf 'Unexpected live smoke Worker name format\n' >&2
  exit 1
fi
if [[ ! "$preview_name" =~ ^live-smoke-[0-9]+-[0-9]+$ ]]; then
  printf 'Unexpected live smoke Preview name format\n' >&2
  exit 1
fi

endpoint="https://api.cloudflare.com/client/v4/accounts/$account_id/workers/workers/$worker_name/previews/$preview_name"
response_file=$(mktemp)
trap 'rm -f -- "$response_file"' EXIT

for attempt in {1..12}; do
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
      printf 'Preview deletion is confirmed (HTTP 404).\n'
      exit 0
      ;;
    200)
      if (( attempt < 12 )); then
        sleep 5
        continue
      fi
      printf 'Preview still exists after teardown.\n' >&2
      exit 1
      ;;
    *)
      printf 'Unexpected Preview deletion verification response: HTTP %s\n' "$status" >&2
      exit 1
      ;;
  esac
done

printf 'Preview deletion was not confirmed.\n' >&2
exit 1
