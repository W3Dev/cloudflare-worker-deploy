# Vercel Deploy Action

A reusable GitHub Action for deploying preview and production environments to Vercel with automatic PR comments and full build control.

## Why Use This Instead of Vercel's Native Integration?

While Vercel provides native GitHub integration, this action gives you **control over where and how your builds happen**:

### Key Advantages

**Build in Your GitHub Actions Environment**
- Builds run on **your GitHub Actions runners**, not Vercel's infrastructure
- Perfect for self-hosted runners with better caching, specific tooling, or compliance requirements
- Use `vercel build` + `vercel deploy --prebuilt` for full control

**Advanced Build Customization**
- Run prebuild scripts (configure git, generate code, set up credentials)
- Override install commands for complex dependency requirements
- Native Bun support alongside npm and pnpm

**Stable Preview URLs**
- Get predictable PR-specific URLs: `pr-123--myapp.vercel.app`
- Vercel's native integration generates random deployment URLs
- Easier to share and reference in testing workflows

**Monorepo-Friendly**
- Explicit `working_directory` support for monorepos
- Fine-grained control over which parts of your repo to deploy

**Smart PR Comments**
- Updates the **same comment** on subsequent pushes (no PR spam)
- Vercel's native integration can create multiple comments per PR

**Workflow Flexibility**
- Integrate with larger workflows (run tests first, conditional deploys, etc.)
- Manual deployment triggers with `workflow_dispatch`

### When to Use Vercel's Native Integration Instead

Use Vercel's native integration if you:
- Want zero configuration
- Don't need custom build steps or environment control
- Prefer Vercel to manage the entire build environment

## Features

- 🏗️ Build in GitHub Actions, deploy to Vercel
- 🚀 Support for both preview and production deployments
- 🔗 Stable preview aliases (`pr-123--myapp.vercel.app`)
- 💬 Smart PR comments that update instead of spam
- 📦 Support for Bun, npm, and pnpm
- ⚙️ Prebuild and predeploy scripts for custom workflows
- 📂 Monorepo support with `working_directory`
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
      
      - uses: W3Dev/vercel-deploy@main
        with:
          vercel_token: ${{ secrets.VERCEL_TOKEN }}
          vercel_org_id: 'team_xxxxx'
          vercel_project_id: 'prj_xxxxx'
```

### Monorepo Usage

```yaml
- uses: W3Dev/vercel-deploy@main
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    working_directory: 'apps/dashboard'
    alias_prefix: 'myapp-dashboard'
```

### With Prebuild Script

```yaml
- uses: W3Dev/vercel-deploy@main
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
- uses: W3Dev/vercel-deploy@main
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    package_manager: 'pnpm'
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

      - uses: W3Dev/vercel-deploy@main
        with:
          vercel_token: ${{ secrets.VERCEL_TOKEN }}
          vercel_org_id: 'team_xxxxx'
          vercel_project_id: 'prj_xxxxx'
          environment: production
```

### Production with Pre-deploy Script

```yaml
- uses: W3Dev/vercel-deploy@main
  with:
    vercel_token: ${{ secrets.VERCEL_TOKEN }}
    vercel_org_id: 'team_xxxxx'
    vercel_project_id: 'prj_xxxxx'
    environment: production
    predeploy_script: |
      echo "Running pre-deployment checks..."
      npm run lint
      npm run test
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
| `predeploy_script` | Script to run before deployment | ❌ | - |
| `install_command` | Custom install command | ❌ | - |
| `environment` | Deployment environment (`preview` or `production`) | ❌ | `preview` |
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
      
      - uses: W3Dev/vercel-deploy@main
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