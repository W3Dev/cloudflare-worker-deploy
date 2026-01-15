# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **GitHub Composite Action** that deploys preview environments to Vercel with automatic PR comments. It's a pure Bash/YAML action with no build system—the action is directly executable through GitHub Actions.

## Repository Structure

- `action.yml` - The entire action logic (264 lines of YAML + Bash)
- `README.md` - User documentation with usage examples

## Development Notes

**No build/test/lint commands exist.** This is not a Node.js project—it's a composite GitHub Action that runs entirely within GitHub Actions runners.

To test changes, you must:
1. Push to a branch
2. Reference the action from a workflow in another repository (or the same repo)
3. Trigger the workflow

## Architecture

The action executes a sequential pipeline:

1. **Context Detection** - Determines PR number from `pull_request` event or manual `workflow_dispatch`
2. **Environment Setup** - Installs Node.js and package manager (Bun/npm/pnpm)
3. **Dependencies** - Runs install command with the selected package manager
4. **Vercel CLI** - Installs globally via npm
5. **Prebuild** - Executes optional custom script (useful for codegen, git config, etc.)
6. **Vercel Config** - Creates `.vercel/project.json` with org/project IDs
7. **Environment Pull** - Fetches preview env vars from Vercel
8. **Build** - Runs `vercel build` to create prebuilt artifact
9. **Deploy** - Runs `vercel deploy --prebuilt`
10. **Alias** - Creates stable PR-specific URL (e.g., `pr-123--myapp.vercel.app`)
11. **PR Comment** - Updates or creates idempotent comment with deployment links

## Key Implementation Details

- **Idempotent PR comments**: Uses HTML marker `<!-- vercel-preview-{projectName} -->` to update same comment on subsequent pushes
- **Package manager detection**: Supports Bun (default), npm, and pnpm with automatic fallback
- **Monorepo support**: `working_directory` input for subdirectory deployments
- **External actions used**: `actions/setup-node@v4`, `oven-sh/setup-bun@v2`, `pnpm/action-setup@v4`, `actions/github-script@v7`

## Action Inputs/Outputs

**Required inputs**: `vercel_token`, `vercel_org_id`, `vercel_project_id`

**Key optional inputs**: `package_manager`, `node_version`, `working_directory`, `alias_prefix`, `prebuild_script`, `install_command`

**Outputs**: `deployment_url`, `alias_url`, `pr_number`
