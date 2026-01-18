# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **GitHub Composite Action** that deploys preview and production environments to Cloudflare Workers with automatic PR comments and stable preview URLs. It's a pure Bash/YAML action with no build system—the action is directly executable through GitHub Actions.

## Repository Structure

- `action.yml` - The entire action logic (YAML + Bash)
- `README.md` - User documentation with usage examples

## Development Notes

**No build/test/lint commands exist.** This is not a Node.js project—it's a composite GitHub Action that runs entirely within GitHub Actions runners.

To test changes, you must:
1. Push to a branch
2. Reference the action from a workflow in another repository (or the same repo)
3. Trigger the workflow

## Architecture

The action executes a sequential pipeline:

1. **Context Detection** - Determines PR number from `pull_request` event or manual `workflow_dispatch`; generates preview alias (e.g., `pr-123` or `{prefix}-pr-123`)
2. **Environment Setup** - Installs Node.js and package manager (Bun/npm/pnpm)
3. **Dependencies** - Runs install command with the selected package manager
4. **Wrangler CLI** - Installs globally via npm/bun/pnpm
5. **Prebuild** - Executes optional custom script (useful for codegen, build, etc.)
6. **Predeploy** - Executes optional custom script before deployment
7. **Deploy** - Uses different strategies based on environment:
   - **Production**: `wrangler deploy` (immediate deployment)
   - **Preview**: `wrangler versions upload --preview-alias` (creates version with aliased URL)
8. **Teardown** - Optional cleanup step for PR close events (Cloudflare auto-manages aliases)
9. **Summary** - Adds deployment info to GitHub Actions summary
10. **PR Comment** - Updates or creates idempotent comment with deployment links

## Key Implementation Details

- **Deployment Strategy**:
  - Production uses `wrangler deploy` for immediate deployment
  - Preview uses `wrangler versions upload --preview-alias` to create isolated versions with stable URLs
  - Secrets and bindings are preserved in previews (same worker, different version)

- **Idempotent PR comments**: Uses HTML marker `<!-- cloudflare-workers-preview-{working_directory} -->` to update same comment on subsequent pushes

- **Package manager detection**: Supports Bun (default), npm, and pnpm with automatic fallback

- **Monorepo support**: `working_directory` input for subdirectory deployments

- **External actions used**: `actions/setup-node@v4`, `oven-sh/setup-bun@v2`, `pnpm/action-setup@v4`, `actions/github-script@v7`

## URL Patterns

- **Production**: `https://{worker-name}.{subdomain}.workers.dev`
- **Preview**: `https://{alias}-{worker-name}.{subdomain}.workers.dev`
  - Default alias: `pr-{number}`
  - With prefix: `{prefix}-pr-{number}`

## Action Inputs/Outputs

**Required inputs**: `cloudflare_api_token`, `cloudflare_account_id`

**Key optional inputs**: `package_manager`, `node_version`, `working_directory`, `alias_prefix`, `prebuild_script`, `predeploy_script`, `install_command`, `environment`, `teardown`, `wrangler_version`

**Outputs**: `deployment_url`, `preview_url`, `version_id`, `pr_number`

## Limitations

- Preview URLs don't work with Durable Objects
- Preview URLs only work on `workers.dev` subdomain

