#!/usr/bin/env bash

set -Eeuo pipefail

mode=${MODE:?MODE is required}
expected_version=${EXPECTED_VERSION:?EXPECTED_VERSION is required}
preview_url=${PREVIEW_URL:?PREVIEW_URL is required}
unique_url=${UNIQUE_URL:?UNIQUE_URL is required}
preview_id=${PREVIEW_ID:?PREVIEW_ID is required}
deployment_id=${DEPLOYMENT_ID:?DEPLOYMENT_ID is required}
preview_urls=${PREVIEW_URLS:?PREVIEW_URLS is required}
deployment_urls=${DEPLOYMENT_URLS:?DEPLOYMENT_URLS is required}

for value_name in PREVIEW_URL UNIQUE_URL PREVIEW_ID DEPLOYMENT_ID; do
  if [[ -z "${!value_name}" ]]; then
    printf '%s must be non-empty\n' "$value_name" >&2
    exit 1
  fi
done

if [[ "$preview_url" == "$unique_url" ]]; then
  printf 'Stable Preview URL and unique deployment URL must differ\n' >&2
  exit 1
fi

PREVIEW_URL="$preview_url" \
UNIQUE_URL="$unique_url" \
PREVIEW_URLS="$preview_urls" \
DEPLOYMENT_URLS="$deployment_urls" \
node --input-type=module <<'NODE'
const previewUrl = process.env.PREVIEW_URL;
const uniqueUrl = process.env.UNIQUE_URL;
const previewUrls = JSON.parse(process.env.PREVIEW_URLS);
const deploymentUrls = JSON.parse(process.env.DEPLOYMENT_URLS);

if (!Array.isArray(previewUrls) || previewUrls.length === 0 || previewUrls[0] !== previewUrl) {
  throw new Error("preview_urls must include preview_url as its first URL");
}
if (!Array.isArray(deploymentUrls) || deploymentUrls.length === 0 || deploymentUrls[0] !== uniqueUrl) {
  throw new Error("deployment_urls must include version_url as its first URL");
}
NODE

body_file=$(mktemp)
trap 'rm -f -- "$body_file"' EXIT

check_url() {
  local url=$1
  local expected=$2
  for attempt in {1..12}; do
    if curl \
      --silent \
      --show-error \
      --fail \
      --location \
      --connect-timeout 10 \
      --max-time 15 \
      --output "$body_file" \
      "$url"; then
      if grep -Fqx -- "$expected" "$body_file"; then
        return 0
      fi
    fi
    if (( attempt < 12 )); then
      sleep 5
    fi
  done
  printf 'URL did not return the expected smoke marker after retries.\n' >&2
  return 1
}

check_url "$preview_url" "SMOKE_VERSION=$expected_version"
check_url "$unique_url" "SMOKE_VERSION=$expected_version"

if [[ "$mode" == update ]]; then
  first_preview_url=${FIRST_PREVIEW_URL:?FIRST_PREVIEW_URL is required for update checks}
  first_unique_url=${FIRST_UNIQUE_URL:?FIRST_UNIQUE_URL is required for update checks}
  first_preview_id=${FIRST_PREVIEW_ID:?FIRST_PREVIEW_ID is required for update checks}
  first_deployment_id=${FIRST_DEPLOYMENT_ID:?FIRST_DEPLOYMENT_ID is required for update checks}

  [[ "$preview_url" == "$first_preview_url" ]] || {
    printf 'Stable Preview URL changed between deployments\n' >&2
    exit 1
  }
  [[ "$preview_id" == "$first_preview_id" ]] || {
    printf 'Preview ID changed between deployments\n' >&2
    exit 1
  }
  [[ "$deployment_id" != "$first_deployment_id" ]] || {
    printf 'Deployment ID did not change between deployments\n' >&2
    exit 1
  }
  [[ "$unique_url" != "$first_unique_url" ]] || {
    printf 'Unique deployment URL did not change between deployments\n' >&2
    exit 1
  }
  check_url "$first_unique_url" 'SMOKE_VERSION=one'
fi

printf '%s Preview URL and deployment URL checks passed.\n' "$mode"
