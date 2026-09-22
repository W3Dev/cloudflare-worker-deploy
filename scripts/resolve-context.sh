#!/usr/bin/env bash

set -euo pipefail

output_path=${GITHUB_OUTPUT:?GITHUB_OUTPUT must point to a writable output file}
environment=${ENVIRONMENT:-}
teardown=${TEARDOWN:-false}
event_name=${EVENT_NAME:-}
pull_request_number=${PR_NUMBER:-}
dispatch_pull_request_number=${DISPATCH_PR_NUMBER:-}
requested_preview_name=${PREVIEW_NAME:-}
alias_prefix=${ALIAS_PREFIX:-}

write_output() {
  printf '%s=%s\n' "$1" "$2" >> "$output_path"
}

fail() {
  printf 'Context error: %s\n' "$1" >&2
  exit 1
}

case "$environment" in
  production|preview) ;;
  '') fail "environment must be either preview or production" ;;
  *) fail "unsupported environment '$environment'; use preview or production" ;;
esac

if [[ "$teardown" != true && "$teardown" != false ]]; then
  fail "teardown must be true or false"
fi

if [[ "$environment" == production ]]; then
  [[ "$teardown" == false ]] || fail "teardown is only supported for preview deployments"
  write_output is_production true
  write_output pr_number ''
  write_output preview_name ''
  exit 0
fi

write_output is_production false

preview_name=$requested_preview_name
if [[ -z "$preview_name" ]]; then
  case "$event_name" in
    pull_request)
      [[ "$pull_request_number" =~ ^[0-9]+$ ]] || fail "pull request events must provide a numeric PR number"
      pr_number=$pull_request_number
      ;;
    workflow_dispatch)
      if [[ -n "$dispatch_pull_request_number" ]]; then
        [[ "$dispatch_pull_request_number" =~ ^[0-9]+$ ]] || fail "workflow_dispatch pr_number must be numeric"
        pr_number=$dispatch_pull_request_number
      else
        pr_number=''
      fi
      ;;
    *)
      pr_number=''
      ;;
  esac

  if [[ -n "$pr_number" ]]; then
    if [[ -n "$alias_prefix" ]]; then
      preview_name="${alias_prefix}-pr-${pr_number}"
    else
      preview_name="pr-${pr_number}"
    fi
  fi
else
  pr_number=''
  if [[ "$event_name" == pull_request ]]; then
    [[ "$pull_request_number" =~ ^[0-9]+$ ]] || fail "pull request events must provide a numeric PR number"
    pr_number=$pull_request_number
  elif [[ "$event_name" == workflow_dispatch && -n "$dispatch_pull_request_number" ]]; then
    [[ "$dispatch_pull_request_number" =~ ^[0-9]+$ ]] || fail "workflow_dispatch pr_number must be numeric"
    pr_number=$dispatch_pull_request_number
  fi
fi

[[ -n "$preview_name" ]] || fail "preview_name is required outside pull_request/workflow_dispatch events"

# Preview names may be branch-like values (for example, `feature/login`).
# Keep that flexibility, but reject control characters before the value is
# written to GITHUB_OUTPUT or passed to a command.
if [[ "$preview_name" =~ [[:cntrl:]] ]]; then
  fail "preview_name cannot contain control characters"
fi

write_output pr_number "$pr_number"
write_output preview_name "$preview_name"
