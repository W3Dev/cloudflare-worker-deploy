#!/usr/bin/env bash

set -Eeuo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

export PATH="$root_dir/tests/fixtures:$PATH"
failures=0

pass() {
  printf 'ok - %s\n' "$1"
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_output() {
  local output_file=$1
  local expected=$2
  local label=$3
  if grep -Fqx -- "$expected" "$output_file"; then
    return 0
  fi
  fail "$label (missing '$expected')"
}

assert_args() {
  local args_file=$1
  local expected=$2
  local label=$3
  local actual
  actual=$(<"$args_file")
  if [[ "$actual" == "$expected" ]]; then
    return 0
  fi
  fail "$label (expected args ${expected@Q}, got ${actual@Q})"
}

run_context_test() {
  local output_file="$tmp_dir/context.out"
  : > "$output_file"
  if env \
    GITHUB_OUTPUT="$output_file" \
    ENVIRONMENT=preview \
    TEARDOWN=false \
    EVENT_NAME=pull_request \
    PR_NUMBER=42 \
    DISPATCH_PR_NUMBER= \
    PREVIEW_NAME= \
    ALIAS_PREFIX=api \
    bash "$root_dir/scripts/resolve-context.sh"; then
    assert_output "$output_file" 'is_production=false' 'pull request context marks preview'
    assert_output "$output_file" 'pr_number=42' 'pull request context preserves PR number'
    assert_output "$output_file" 'preview_name=api-pr-42' 'pull request context derives preview name'
    pass 'pull request context'
  else
    fail 'pull request context unexpectedly failed'
  fi

  local unsafe_output="$tmp_dir/context-unsafe.out"
  : > "$unsafe_output"
  if env \
    GITHUB_OUTPUT="$unsafe_output" \
    ENVIRONMENT=preview \
    TEARDOWN=false \
    EVENT_NAME=workflow_dispatch \
    PR_NUMBER= \
    DISPATCH_PR_NUMBER= \
    PREVIEW_NAME=$'unsafe\nname' \
    ALIAS_PREFIX= \
    bash "$root_dir/scripts/resolve-context.sh"; then
    fail 'control-character preview name is rejected'
  else
    pass 'control-character preview name is rejected'
  fi
}

run_version_test() {
  local args_file="$tmp_dir/version.args"
  : > "$args_file"
  if env \
    MOCK_ARGS_FILE="$args_file" \
    MOCK_WRANGLER_VERSION=4.135.0 \
    REQUIRED_WRANGLER_VERSION=4.135.0 \
    bash "$root_dir/scripts/check-wrangler-version.sh"; then
    pass 'minimum Wrangler version is accepted'
  else
    fail 'minimum Wrangler version is accepted'
  fi

  if env \
    MOCK_ARGS_FILE="$args_file" \
    MOCK_WRANGLER_VERSION=4.134.9 \
    REQUIRED_WRANGLER_VERSION=4.135.0 \
    bash "$root_dir/scripts/check-wrangler-version.sh"; then
    fail 'older Wrangler version is rejected'
  else
    pass 'older Wrangler version is rejected'
  fi
}

run_deploy() {
  local label=$1
  local mode=$2
  local environment=$3
  local preview_name=$4
  local expected_status=$5
  local output_file="$tmp_dir/$label.output"
  local args_file="$tmp_dir/$label.args"
  local actual_status
  : > "$output_file"
  : > "$args_file"

  if env \
    MOCK_MODE="$mode" \
    MOCK_ARGS_FILE="$args_file" \
    GITHUB_OUTPUT="$output_file" \
    ACTION_PATH="$root_dir" \
    ENVIRONMENT="$environment" \
    TEARDOWN=false \
    PREVIEW_NAME="$preview_name" \
    bash "$root_dir/scripts/deploy.sh"; then
    actual_status=0
  else
    actual_status=$?
  fi

  if [[ "$actual_status" != "$expected_status" ]]; then
    fail "$label exit status (expected $expected_status, got $actual_status)"
  fi
  RUN_OUTPUT_FILE=$output_file
  RUN_ARGS_FILE=$args_file
}

run_teardown() {
  local label=$1
  local mode=$2
  local expected_status=$3
  local output_file="$tmp_dir/$label.output"
  local args_file="$tmp_dir/$label.args"
  local actual_status
  : > "$output_file"
  : > "$args_file"

  if env \
    MOCK_MODE="$mode" \
    MOCK_ARGS_FILE="$args_file" \
    GITHUB_OUTPUT="$output_file" \
    ACTION_PATH="$root_dir" \
    ENVIRONMENT=preview \
    TEARDOWN=true \
    PREVIEW_NAME=feature/login \
    bash "$root_dir/scripts/deploy.sh"; then
    actual_status=0
  else
    actual_status=$?
  fi

  if [[ "$actual_status" != "$expected_status" ]]; then
    fail "$label exit status (expected $expected_status, got $actual_status)"
  fi
  RUN_OUTPUT_FILE=$output_file
  RUN_ARGS_FILE=$args_file
}

run_context_test
run_version_test

run_deploy preview_success preview-success preview feature/login 0
assert_args "$RUN_ARGS_FILE" $'preview\n--name\nfeature/login\n--json' 'native preview command and safe name'
assert_output "$RUN_OUTPUT_FILE" 'preview_url=https://feature-login.example.workers.dev' 'stable preview URL is exposed'
assert_output "$RUN_OUTPUT_FILE" 'deployment_url=https://feature-login.example.workers.dev' 'deployment_url preserves the v1 primary URL contract'
assert_output "$RUN_OUTPUT_FILE" 'version_url=https://deployment-id-feature-login.example.workers.dev' 'unique deployment URL is exposed through version_url'
assert_output "$RUN_OUTPUT_FILE" 'version_id=deployment-id' 'version_id maps to the current deployment ID'
assert_output "$RUN_OUTPUT_FILE" 'preview_id=preview-id' 'preview ID is exposed'
assert_output "$RUN_OUTPUT_FILE" 'deployment_id=deployment-id' 'deployment ID is exposed'
pass 'structured preview success outputs'

run_deploy preview_no_urls preview-no-urls preview feature-login 0
assert_output "$RUN_OUTPUT_FILE" 'preview_url=' 'URL-less previews are accepted'
assert_output "$RUN_OUTPUT_FILE" 'preview_urls=[]' 'URL-less preview array is preserved'
pass 'URL-less preview success'

run_deploy preview_failure preview-failure preview feature-login 19
assert_args "$RUN_ARGS_FILE" $'preview\n--name\nfeature-login\n--json' 'preview errors do not fall back to production deploy'
pass 'preview command failure is honored'

run_deploy preview_malformed preview-malformed preview feature-login 1
pass 'malformed preview JSON is rejected'

run_teardown teardown_success teardown-success 0
assert_args "$RUN_ARGS_FILE" $'preview\ndelete\n--name\nfeature/login\n--skip-confirmation' 'preview teardown uses native delete command'
pass 'preview teardown succeeds'

run_teardown teardown_failure teardown-failure 23
pass 'preview teardown failure is honored'

run_deploy production_success production-success production '' 0
assert_args "$RUN_ARGS_FILE" $'deploy' 'production deploy command is preserved'
assert_output "$RUN_OUTPUT_FILE" 'deployment_url=https://worker.example.workers.dev' 'production URL is exposed'
pass 'production success'

run_deploy production_route production-route production '' 0
assert_output "$RUN_OUTPUT_FILE" 'deployment_url=' 'route-based production deploy may have no workers.dev URL'
pass 'route-based production success'

run_deploy production_failure production-failure production '' 17
pass 'production command failure is honored'

if (( failures > 0 )); then
  printf '%s test assertion(s) failed\n' "$failures" >&2
  exit 1
fi

printf 'All action tests passed.\n'
