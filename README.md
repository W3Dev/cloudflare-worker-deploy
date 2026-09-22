# Cloudflare Workers Deploy Action v2

A reusable GitHub Action for deploying production Workers and named Cloudflare Worker Previews from GitHub Actions. Preview deployments use Wrangler 4.135.0 or newer and return both the stable Preview URL and the unique URL for the current deployment.

## Why Use This Action?

### Key Advantages

**Native Worker Previews**
- Creates or updates a named Preview with `wrangler preview --name ... --json`
- Keeps a stable Preview URL pointed at the latest deployment
- Exposes the immutable unique deployment URL and resource IDs
- Uses the `previews` block in your Wrangler configuration for Preview-safe settings

**Explicit lifecycle**
- Accepts `preview_name` directly, or derives `pr-{number}` for pull request events
- Deletes a Preview with `wrangler preview delete --name ... --skip-confirmation`
- Fails on Wrangler errors and never falls back from a failed Preview to production

**Smart PR Comments**
- Updates the **same comment** on subsequent pushes (no PR spam)
- Shows the Preview URL, unique deployment URL, Preview name, and IDs

**Workflow Flexibility**
- Integrate with larger workflows (run tests first, conditional deploys, etc.)
- Manual deployment triggers with `workflow_dispatch`
- Monorepo support with `working_directory`

## Features

- Deploy named Worker Previews and production Workers
- Support Preview configuration, selective binding isolation, and custom Preview domains
- Smart PR comments that update instead of spam
- Support for Bun, npm, and pnpm
- Prebuild and predeploy scripts for custom workflows
- Monorepo support with `working_directory`
- GitHub Actions summary

v2 requires Node.js 22 and Wrangler 4.135.0 or newer. The action defaults to Wrangler 4.135.0; pin a later version with `wrangler_version` after validating it in your workflows.

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

      - uses: w3dev/cloudflare-worker-deploy@v2
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

On a `pull_request` event, v2 derives `pr-{number}` unless `preview_name` is supplied. For a push or manual workflow, provide an explicit name:

```yaml
- uses: w3dev/cloudflare-worker-deploy@v2
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    preview_name: feature-login
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

      - uses: w3dev/cloudflare-worker-deploy@v2
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          environment: production
```

### Monorepo Usage

```yaml
- uses: w3dev/cloudflare-worker-deploy@v2
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    working_directory: 'apps/api'
    alias_prefix: 'api'  # Derives api-pr-123 on pull_request events
```

### With Prebuild Script

```yaml
- uses: w3dev/cloudflare-worker-deploy@v2
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    prebuild_script: |
      npm run generate
      npm run build
```

### Using pnpm

```yaml
- uses: w3dev/cloudflare-worker-deploy@v2
  with:
    cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    package_manager: 'pnpm'
```

### With Pre-deploy Script

```yaml
- uses: w3dev/cloudflare-worker-deploy@v2
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
- You want to deploy from a different branch (for example, `main`) to update a named Preview
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

      - uses: w3dev/cloudflare-worker-deploy@v2
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

When triggered manually with a PR number, the action derives `pr-{number}`. You can set `preview_name` instead when the Preview should not be tied to a PR number. The action updates the named Preview and posts its stable and unique URLs to the PR.

To delete the Preview when the PR closes, add a second workflow or job for the `closed` event and pass the same name with `teardown: true`:

```yaml
on:
  pull_request:
    types: [closed]

permissions:
  contents: read
  pull-requests: write

jobs:
  delete-preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: w3dev/cloudflare-worker-deploy@v2
        with:
          cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          cloudflare_account_id: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          teardown: true
```

The delete job derives the same `pr-{number}` name from the closed pull request. For an explicit name, pass the same `preview_name` used during deployment.

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cloudflare_api_token` | Cloudflare API token with Workers edit permission | Yes | - |
| `cloudflare_account_id` | Cloudflare Account ID | Yes | - |
| `teardown` | Set to `true` to handle PR close cleanup | No | `false` |
| `package_manager` | `bun`, `npm`, or `pnpm` | No | `bun` |
| `node_version` | Node.js major version (v2 requires 22 or newer) | No | `22` |
| `working_directory` | Build directory | No | `.` |
| `alias_prefix` | Prefix for an automatically derived PR Preview name | No | - |
| `preview_name` | Explicit Preview name; required outside PR/workflow_dispatch name derivation | No | - |
| `prebuild_script` | Script to run before deployment | No | - |
| `predeploy_script` | Script to run before deployment | No | - |
| `install_command` | Custom install command | No | - |
| `environment` | Deployment environment (`preview` or `production`) | No | `preview` |
| `github_token` | Token for PR comments | No | `github.token` |
| `wrangler_version` | Wrangler CLI version (must be `4.135.0` or newer for Preview mode) | No | `4.135.0` |
| `pnpm_version` | pnpm version. Leave empty to use `packageManager` from `package.json` | No | - |

## Outputs

| Output | Description |
|--------|-------------|
| `deployment_url` | Stable Preview URL in preview mode, or the production workers.dev URL when Wrangler emits one |
| `preview_url` | Stable URL for the named Preview, pointing to its latest deployment |
| `version_url` | Unique URL for the current Preview deployment (v1 compatibility name) |
| `version_id` | Current Preview deployment ID (v1 compatibility name) |
| `preview_name` | Resolved Preview name |
| `preview_id` | Preview resource ID |
| `deployment_id` | Current Preview deployment resource ID |
| `preview_urls` | JSON array of all stable Preview URLs |
| `deployment_urls` | JSON array of all unique Preview deployment URLs |
| `pr_number` | The PR number (if applicable) |

## Preview URLs and configuration

`wrangler preview` returns two URL classes:

- **Preview URL**: stable for the named Preview and points to its latest deployment.
- **Unique Deployment URL**: immutable for one deployment and useful for comparing earlier deployments.

The URLs are optional. A Worker can be deployed successfully without an active Preview URL when Preview URLs are disabled or no route/domain is configured. Inspect `preview_urls` and `deployment_urls` before treating an empty URL as a deployment failure.

Configure Preview-safe values in the Worker configuration committed with the branch. The `previews` block can override variables, bindings, observability, limits, placement, and cache settings:

```jsonc
{
  "name": "my-api",
  "main": "src/index.ts",
  "compatibility_date": "2026-09-22",
  "vars": { "ENVIRONMENT": "production" },
  "previews": {
    "vars": { "ENVIRONMENT": "preview" },
    "kv_namespaces": [
      { "binding": "CACHE", "id": "preview-kv-namespace-id" }
    ],
    "observability": { "enabled": true }
  }
}
```

Keep production resources out of the Preview configuration unless sharing them is intentional. Use Preview-safe KV, D1, R2, Hyperdrive, Vectorize, queues, and other bindings; Durable Objects and container resources can be provisioned per Preview according to Cloudflare's resource rules. D1 migrations still need to be applied to the database used by the Preview.

Preview secrets are managed by Wrangler's Preview commands rather than committed to this action's inputs. Set shared values with `wrangler preview base-config secret put NAME` or a one-Preview value with `wrangler preview secret put NAME --name PREVIEW_NAME`. The action does not print or accept secret values.

Preview domains can use `workers.dev` or a configured custom Preview domain. Enable Preview traffic for the relevant route/custom domain in Wrangler and use the returned `preview_urls` array instead of constructing a URL from the Worker name.

## Prerequisites

1. A Cloudflare account with Workers enabled
2. A `wrangler.jsonc` or `wrangler.toml` file in your project (or working directory)
3. A Cloudflare API token with Workers edit permission
4. Your Cloudflare Account ID
5. Node.js 22 or newer and Wrangler 4.135.0 or newer for Preview mode

Read Cloudflare's [Worker Previews getting started guide](https://developers.cloudflare.com/workers/previews/get-started/), [configuration guide](https://developers.cloudflare.com/workers/previews/configuration/), [resource isolation guidance](https://developers.cloudflare.com/workers/previews/resources/), [custom domain guide](https://developers.cloudflare.com/workers/previews/custom-domains/), and [test/debug guide](https://developers.cloudflare.com/workers/previews/test-and-debug/) before enabling Preview traffic for a production Worker.

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

      - uses: w3dev/cloudflare-worker-deploy@v2
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

## Deployment Strategy

### Preview Deployments

Uses `wrangler preview --name "$preview_name" --json` to create or update a named Preview without changing production traffic. The structured result contains `{ preview, deployment }`; the action validates both resources, exposes their IDs, and maps `preview.urls[0]` to `preview_url` and `deployment.urls[0]` to the v1-compatible `version_url`.

The command reads the branch's `previews` configuration, so Preview values and bindings are selected by the Worker configuration rather than copied from production by this action. A Preview deployment error is returned as a failed action and is never retried as production.

### Preview teardown

With `teardown: true`, the action runs `wrangler preview delete --name "$preview_name" --skip-confirmation`. This deletes the named Preview and all deployments associated with it. The caller should invoke teardown from a pull request `closed` workflow and use the same resolved name.

### Production Deployments

Uses `wrangler deploy` to:
- Upload and immediately deploy to production
- Deploy to the main worker URL

Production keeps the existing command path and honors Wrangler's exit code. Route-based Workers can deploy successfully without a `workers.dev` URL; in that case `deployment_url` is empty and the action still succeeds.

## Migrating from v1

The existing `v1` tag remains the alias-based action. Pin workflows that must keep that behavior to `w3dev/cloudflare-worker-deploy@v1` (or an exact commit SHA). v2 workflows should use `@v2` and migrate as follows:

1. Replace alias-based expectations with a named Preview and set `preview_name` for non-PR events.
2. Upgrade Wrangler to 4.135.0 or newer and add a `previews` block to the Worker configuration.
3. Map `preview_url` to the stable Preview URL and `version_url`/`deployment_urls` to the unique current deployment URL when needed. `version_id` remains available as a compatibility alias for `deployment_id`.
4. Add a closed-PR teardown job if Preview resources should be deleted immediately.
5. Review variables, secrets, storage, Durable Objects, containers, custom domains, and observability for Preview-safe values before enabling the workflow.

## Debugging a Preview

Start with the action summary and PR comment: they include the Preview name, stable URL, unique deployment URL, Preview ID, deployment ID, and commit SHA. If the action succeeds but no URL is returned, inspect `preview_urls`/`deployment_urls` and the Worker `preview_urls` or route configuration. If runtime behavior is incomplete, compare the branch's `previews` bindings with the production bindings and use the Preview observability settings described in Cloudflare's [test and debug guide](https://developers.cloudflare.com/workers/previews/test-and-debug/).

The local validation suite uses mocked Wrangler commands and never contacts Cloudflare. A real deployment still requires a consuming workflow with valid credentials and a Worker configuration.

## License

MIT
