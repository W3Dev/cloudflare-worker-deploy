# Vercel Preview Deploy Action

A reusable GitHub Action for deploying preview environments to Vercel with automatic PR comments.

## Features

- 🚀 Deploy preview environments on PR
- 💬 Auto-comment on PRs with deployment URLs
- 📦 Support for Bun, npm, and pnpm
- 🔗 Custom preview aliases (`pr-123--myapp.vercel.app`)
- ⚙️ Optional prebuild scripts
- 📊 GitHub Actions summary

## Usage

### Basic Usage

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
      
      - uses: W3Dev/vercel-preview-action@v1
        with:
          vercel_token: ${{ secrets.VERCEL_TOKEN }}
          vercel_org_id: 'team_xxxxx'
          vercel_project_id: 'prj_xxxxx'
```

### Monorepo Usage

```yaml
- uses: W3Dev/vercel-preview-action@v1
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    working_directory: 'apps/dashboard'
    alias_prefix: 'myapp-dashboard'
```

### With Prebuild Script

```yaml
- uses: W3Dev/vercel-preview-action@v1
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    prebuild_script: |
      git config --global user.email "ci@example.com"
      git config --global user.name "CI Bot"
```

### Using pnpm

```yaml
- uses: W3Dev/vercel-preview-action@v1
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    package_manager: 'pnpm'
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `vercel_token` | Vercel API token | ✅ | - |
| `vercel_org_id` | Vercel Organization/Team ID | ✅ | - |
| `vercel_project_id` | Vercel Project ID | ✅ | - |
| `vercel_project_name` | Project name for linking | ❌ | repo name |
| `package_manager` | `bun`, `npm`, or `pnpm` | ❌ | `bun` |
| `node_version` | Node.js version | ❌ | `22` |
| `working_directory` | Build directory | ❌ | `.` |
| `alias_prefix` | Prefix for preview alias | ❌ | - |
| `prebuild_script` | Script to run before build | ❌ | - |
| `install_command` | Custom install command | ❌ | - |
| `github_token` | Token for PR comments | ❌ | `github.token` |

## Outputs

| Output | Description |
|--------|-------------|
| `deployment_url` | The Vercel deployment URL |
| `alias_url` | The aliased preview URL |
| `pr_number` | The PR number (if applicable) |

## Example: Full Workflow

```yaml
name: Dashboard Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'apps/dashboard/**'
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
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - uses: W3Dev/vercel-preview-action@v1
        id: deploy
        with:
          vercel_token: ${{ secrets.VERCEL_TOKEN }}
          vercel_org_id: 'team_M1i3qUTW4i3A6mETy54E1Fy8'
          vercel_project_id: 'prj_xxxxx'
          package_manager: 'bun'
          working_directory: 'apps/dashboard'
          alias_prefix: 'myapp'
      
      - name: Use deployment URL
        run: echo "Deployed to ${{ steps.deploy.outputs.deployment_url }}"
```

## License

MIT