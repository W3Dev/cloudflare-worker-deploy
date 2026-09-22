#!/usr/bin/env bash

set -euo pipefail

environment=${ENVIRONMENT:-}
teardown=${TEARDOWN:-false}
preview_name=${PREVIEW_NAME:-}
output_path=${GITHUB_OUTPUT:?GITHUB_OUTPUT must point to a writable output file}
action_path=${ACTION_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}

write_output() {
  printf '%s=%s\n' "$1" "$2" >> "$output_path"
}

fail() {
  printf 'Deployment error: %s\n' "$1" >&2
  exit 1
}

case "$environment" in
  production|preview) ;;
  *) fail "environment must be either preview or production" ;;
esac

if [[ "$teardown" == true ]]; then
  [[ "$environment" == preview ]] || fail "teardown is only supported for preview deployments"
  [[ -n "$preview_name" ]] || fail "preview_name is required to delete a Preview"

  if wrangler preview delete --name "$preview_name" --skip-confirmation; then
    printf 'Deleted Preview %s\n' "$preview_name"
  else
    status=$?
    printf 'Failed to delete Preview %s (exit code %s)\n' "$preview_name" "$status" >&2
    exit "$status"
  fi
  exit 0
fi

if [[ "$environment" == production ]]; then
  deployment_output=''
  if deployment_output=$(wrangler deploy 2>&1); then
    status=0
  else
    status=$?
  fi

  printf '%s\n' "$deployment_output"
  if (( status != 0 )); then
    printf 'Production deployment failed with exit code %s\n' "$status" >&2
    exit "$status"
  fi

  clean_output=$(printf '%s\n' "$deployment_output" | sed -E 's/\x1B\[[0-9;?]*[ -/]*[@-~]//g; s/\r//g')
  deployment_url=$(printf '%s\n' "$clean_output" | grep -oE 'https://[^[:space:]]+\.workers\.dev' | head -n 1 || true)
  write_output url "$deployment_url"
  write_output deployment_url "$deployment_url"
  write_output preview_url ''
  write_output version_url ''
  write_output version_id ''
  write_output preview_id ''
  write_output deployment_id ''
  write_output preview_urls '[]'
  write_output deployment_urls '[]'
  exit 0
fi

[[ -n "$preview_name" ]] || fail "preview_name is required for preview deployments"

json_file=$(mktemp)
stderr_file=$(mktemp)
cleanup() {
  rm -f -- "$json_file" "$stderr_file"
}
trap cleanup EXIT

if wrangler preview --name "$preview_name" --json >"$json_file" 2>"$stderr_file"; then
  status=0
else
  status=$?
fi

if [[ -s "$stderr_file" ]]; then
  cat "$stderr_file" >&2
fi
if [[ -s "$json_file" ]]; then
  cat "$json_file"
fi

if (( status != 0 )); then
  printf 'Preview deployment failed with exit code %s\n' "$status" >&2
  exit "$status"
fi

node "$action_path/scripts/parse-preview-json.mjs" "$json_file" "$output_path"

# Keep the old internal step output available to workflows that inspect the
# composite step directly. The public action output uses deployment_url.
preview_deployment_url=$(sed -n 's/^deployment_url=//p' "$output_path" | tail -n 1)
write_output url "$preview_deployment_url"
