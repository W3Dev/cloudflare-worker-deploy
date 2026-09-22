# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **GitHub Composite Action** that deploys named Worker Previews and production environments to Cloudflare Workers with automatic PR comments and structured URL outputs. The action is YAML plus small Bash/Node helpers and runs directly on GitHub Actions runners.

## Repository Structure

- `action.yml` - Composite action metadata and orchestration
- `README.md` - User documentation with usage examples
- `scripts/resolve-context.sh` - Safe event and Preview-name resolution
- `scripts/check-node-version.sh` - Node.js 22 minimum check
- `scripts/check-wrangler-version.sh` - Wrangler 4.135.0 minimum check
- `scripts/deploy.sh` - Preview, teardown, and production command paths
- `scripts/parse-preview-json.mjs` - Structured Wrangler result validation and output mapping
- `tests/` - Mocked command tests and metadata/script validation
- `.github/workflows/validate.yml` - CI validation for metadata, tests, shell, and workflow syntax

## Development Notes

Run the local checks before committing:

```bash
bash tests/validate_action.sh
bash tests/test_action.sh
git diff --check
```

The tests mock Wrangler and never contact Cloudflare. A real deployment still requires a consuming workflow with valid credentials.

## Architecture

The action executes a sequential pipeline:

1. **Context Detection** - Resolves `preview_name` from the explicit input or a PR number (`pr-{number}`), rejecting control characters and invalid environment/teardown combinations
2. **Environment Setup** - Installs Node.js 22+ and the selected package manager (Bun/npm/pnpm)
3. **Dependencies** - Runs the selected install command, without evaluating it inside generated action source
4. **Wrangler CLI** - Installs the requested version and enforces Wrangler 4.135.0+
5. **Prebuild** - Executes the optional custom script for deployment runs
6. **Predeploy** - Executes the optional custom script before deployment
7. **Deploy** - Uses `wrangler preview --name ... --json` for Preview or `wrangler deploy` for production; Preview errors never fall back to production
8. **Teardown** - Uses `wrangler preview delete --name ... --skip-confirmation`
9. **Summary** - Adds Preview/production URLs, IDs, name, and commit to the GitHub Actions summary
10. **PR Comment** - Updates or creates an idempotent comment with stable and unique Preview links

## Key Implementation Details

- **Deployment Strategy**:
  - Production uses `wrangler deploy` and honors its exit code
  - Preview uses `wrangler preview --name "$PREVIEW_NAME" --json` and validates `{ preview, deployment }`
  - `preview.urls` is the stable URL list; `deployment.urls` is the unique URL list
  - `version_url` and `version_id` remain v1-compatible output names mapped to the current deployment URL/ID

- **Idempotent PR comments**: Uses an HTML marker containing the working directory and Preview name to update the same comment on subsequent pushes

- **Package manager detection**: Supports Bun (default), npm, and pnpm; invalid values fail fast

- **Monorepo support**: `working_directory` input for subdirectory deployments

- **External actions used**: `actions/setup-node@v4`, `oven-sh/setup-bun@v2`, `pnpm/action-setup@v4`, `actions/github-script@v7`

## Action Inputs/Outputs

**Required inputs**: `cloudflare_api_token`, `cloudflare_account_id`

**Key optional inputs**: `package_manager`, `node_version`, `working_directory`, `alias_prefix`, `preview_name`, `prebuild_script`, `predeploy_script`, `install_command`, `environment`, `teardown`, `wrangler_version`

**Outputs**: `deployment_url`, `preview_url`, `version_url`, `version_id`, `preview_name`, `preview_id`, `deployment_id`, `preview_urls`, `deployment_urls`, `pr_number`

## Preview configuration

Preview-safe variables, storage bindings, Durable Objects, containers, secrets, observability, and custom domains are configured through the Worker `previews` block and Wrangler Preview commands. Keep this action focused on lifecycle orchestration; do not add secret values to action inputs or logs. See the README links to Cloudflare's Preview configuration, resources, custom domains, and debugging documentation.
