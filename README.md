# Cloudflare Workers Deploy Action

A reusable GitHub Action for deploying preview and production environments to Cloudflare Workers with automatic PR comments and stable preview URLs.

## Why Use This Action?

### Key Advantages

**Stable Preview URLs with Aliases**
- Get predictable PR-specific URLs: `pr-123-{worker}.{subdomain}.workers.dev`
- Aliases persist across commits to the same PR
- Secrets and bindings are preserved (same worker, different version)

**Version-Based Preview Strategy**
- Uses `wrangler versions upload --preview-alias` for previews
- Creates isolated versions without affecting production traffic
- Uses `wrangler deploy` for production deployments

**Smart PR Comments**
- Updates the **same comment** on subsequent pushes (no PR spam)
- Shows preview URL and version ID

**Workflow Flexibility**
- Integrate with larger workflows (run tests first, conditional deploys, etc.)
- Manual deployment triggers with `workflow_dispatch`
- Monorepo support with `working_directory`

## Features

- Deploy to Cloudflare Workers with stable preview URLs
- Support for both preview and production deployments
- Stable preview aliases (`pr-123-{worker}.{subdomain}.workers.dev`)
- Smart PR comments that update instead of spam
- Support for Bun, npm, and pnpm
- Prebuild and predeploy scripts for custom workflows
- Monorepo support with `working_directory`
- GitHub Actions summary

## Usage

### Basic Preview Deployment

```yaml
name: Deploy Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: w3dev/cloudflare-worker-deploy@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

### Production Deployment (on merge to main)

```yaml
name: Deploy Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: w3dev/cloudflare-worker-deploy@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          environment: production
```

### Monorepo Usage

```yaml
- uses: w3dev/cloudflare-worker-deploy@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    working_directory: 'apps/api'
    alias_prefix: 'api'  # Creates api-pr-123-{worker}.{subdomain}.workers.dev
```

### With Prebuild Script

```yaml
- uses: w3dev/cloudflare-worker-deploy@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    prebuild_script: |
      npm run generate
      npm run build
```

### Using pnpm

```yaml
- uses: w3dev/cloudflare-worker-deploy@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    package_manager: 'pnpm'
```

### With Pre-deploy Script

```yaml
- uses: w3dev/cloudflare-worker-deploy@main
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    environment: production
    predeploy_script: |
      echo "Running pre-deployment checks..."
      npm run lint
      npm run test
```

### Manual Deployment for a Specific PR

You can manually trigger a deployment for an existing PR using `workflow_dispatch`. This is useful when:
- You need to redeploy a PR without pushing a new commit
- You want to deploy from a different branch (e.g., `main`) to test against a PR's preview alias
- CI failed for unrelated reasons and you want to retry

Add `workflow_dispatch` with a `pr_number` input to your workflow:

```yaml
name: Deploy Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]
  workflow_dispatch:
    inputs:
      pr_number:
        description: 'PR number to deploy'
        required: false

permissions:
  contents: read
  pull-requests: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: w3dev/cloudflare-worker-deploy@main
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

When triggered manually with a PR number, the action will:
1. Generate the preview alias (`pr-{number}`)
2. Deploy a new version with that alias
3. Post/update the comment on the specified PR

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cloudflare_api_token` | Cloudflare API token with Workers edit permission | Yes | - |
| `cloudflare_account_id` | Cloudflare Account ID | Yes | - |
| `teardown` | Set to `true` to handle PR close cleanup | No | `false` |
| `package_manager` | `bun`, `npm`, or `pnpm` | No | `bun` |
| `node_version` | Node.js version | No | `22` |
| `working_directory` | Build directory | No | `.` |
| `alias_prefix` | Prefix for preview alias | No | - |
| `prebuild_script` | Script to run before deployment | No | - |
| `predeploy_script` | Script to run before deployment | No | - |
| `install_command` | Custom install command | No | - |
| `environment` | Deployment environment (`preview` or `production`) | No | `preview` |
| `github_token` | Token for PR comments | No | `github.token` |
| `wrangler_version` | Wrangler CLI version (e.g., `4.42.0`) | No | `latest` |

## Outputs

| Output | Description |
|--------|-------------|
| `deployment_url` | The Cloudflare Workers deployment URL |
| `preview_url` | The aliased preview URL (for preview deployments) |
| `version_url` | The version-specific preview URL (for preview deployments) |
| `version_id` | The uploaded version ID |
| `pr_number` | The PR number (if applicable) |

## URL Patterns

- **Production**: `https://{worker-name}.{subdomain}.workers.dev`
- **Preview (aliased)**: `https://{alias}-{worker-name}.{subdomain}.workers.dev`
  - Example: `https://pr-123-my-api.my-account.workers.dev`
  - With prefix: `https://api-pr-123-my-api.my-account.workers.dev`

## Prerequisites

1. A Cloudflare account with Workers enabled
2. A `wrangler.toml` file in your project (or working directory)
3. A Cloudflare API token with Workers edit permission
4. Your Cloudflare Account ID

### Creating a Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Create a token with the following permissions:
   - Account > Workers Scripts > Edit
   - Account > Account Settings > Read
3. Copy the token and add it as a GitHub secret (`CLOUDFLARE_API_TOKEN`)

### Finding Your Account ID

Your Account ID is visible in the Cloudflare dashboard URL when you're viewing your account:
`https://dash.cloudflare.com/{account-id}/...`

Or run `wrangler whoami` locally to see it.

## Example: Full Workflow

```yaml
name: API Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'apps/api/**'
  workflow_dispatch:
    inputs:
      pr_number:
        description: 'PR number to deploy'
        required: false

permissions:
  contents: read
  pull-requests: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: w3dev/cloudflare-worker-deploy@main
        id: deploy
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          package_manager: 'bun'
          working_directory: 'apps/api'
          alias_prefix: 'api'

      - name: Use deployment URL
        run: echo "Deployed to ${{ steps.deploy.outputs.deployment_url }}"
```

## Limitations

From Cloudflare documentation:

- **Durable Objects**: Preview URLs are **not generated** for Workers with Durable Objects
- **Logging**: Cannot view logs for preview URLs (no `wrangler tail`, Workers Logs, or Logpush)
- **Domain**: Preview URLs only work on `workers.dev` subdomain
- **Wrangler version**: Requires Wrangler v4.21.0+ for aliased preview URLs
- **Alias cleanup**: Cloudflare auto-cleans older aliases (keeps last 1000)

## Deployment Strategy

### Preview Deployments

Uses `wrangler versions upload --preview-alias` to:
- Create a new version without deploying to production
- Get a stable aliased preview URL
- **Preserve secrets and bindings** (same worker, different version)

### Production Deployments

Uses `wrangler deploy` to:
- Upload and immediately deploy to production
- Deploy to the main worker URL

## License

MIT
