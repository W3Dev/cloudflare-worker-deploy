#!/usr/bin/env bash

set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

ruby - "$root_dir/action.yml" <<'RUBY'
require "yaml"

path = ARGV.fetch(0)
action = YAML.load_file(path)
abort "action must be a composite action" unless action.dig("runs", "using") == "composite"
abort "action must define steps" unless action.dig("runs", "steps").is_a?(Array)

%w[preview_name environment wrangler_version].each do |name|
  abort "missing input: #{name}" unless action.fetch("inputs").key?(name)
end

%w[deployment_url preview_url version_url version_id preview_name preview_id deployment_id preview_urls deployment_urls].each do |name|
  abort "missing output: #{name}" unless action.fetch("outputs").key?(name)
end

puts "Action metadata is valid (#{action.fetch("runs").fetch("steps").length} steps)."
RUBY

summary_script="$tmp_dir/deployment-summary.sh"
ruby - "$root_dir/action.yml" "$summary_script" <<'RUBY'
require "yaml"

action_path, output_path = ARGV
action = YAML.load_file(action_path)
step = action.fetch("runs").fetch("steps").find { |candidate| candidate["name"] == "Add deployment summary" }
abort "missing Add deployment summary step" unless step && step["run"].is_a?(String)
File.write(output_path, step.fetch("run"))
RUBY

bash -n "$summary_script"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s bash "$summary_script"
fi

summary_output="$tmp_dir/summary.md"
env \
  GITHUB_STEP_SUMMARY="$summary_output" \
  ENVIRONMENT=preview \
  PREVIEW_NAME='feature/login' \
  PREVIEW_URL='https://feature-login.example.workers.dev' \
  DEPLOYMENT_URL='https://feature-login.example.workers.dev' \
  VERSION_URL='https://deployment-id-feature-login.example.workers.dev' \
  VERSION_ID='deployment-id' \
  PREVIEW_ID='preview-id' \
  COMMIT_SHA='abc123' \
  bash -euo pipefail "$summary_script"

grep -Fqx -- "| **Preview name** | \`feature/login\` |" "$summary_output"
printf 'Embedded deployment summary shell passes syntax and execution checks.\n'

for script in "$root_dir"/scripts/*.sh "$root_dir"/tests/*.sh "$root_dir"/tests/fixtures/wrangler "$root_dir"/tests/live-preview-smoke/scripts/*.sh; do
  bash -n "$script"
done
node --check "$root_dir/scripts/parse-preview-json.mjs"
node --check "$root_dir/tests/fixtures/live-worker/src/index.js"

if grep -R -n -F -- 'wrangler versions upload --preview-alias' "$root_dir/action.yml" "$root_dir/scripts"; then
  printf 'legacy alias upload command remains in v2 implementation\n' >&2
  exit 1
fi

if grep -R -n -F -- "eval \"\$INSTALL_CMD\"" "$root_dir/action.yml"; then
  printf 'unsafe install command evaluation remains in action metadata\n' >&2
  exit 1
fi

printf 'Action scripts and metadata pass local validation.\n'
