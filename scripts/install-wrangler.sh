#!/usr/bin/env bash

# Installs Wrangler into a private directory and exposes it on PATH.
#
# This deliberately avoids `<package manager> install -g`. Global install
# directories (for example ~/.bun/install/global) are shared between jobs on
# self-hosted runners and can be left unwritable, which fails with EACCES
# before anything is deployed.

set -euo pipefail

pkg_manager=${PKG_MANAGER:-bun}
wrangler_version=${WRANGLER_VERSION:-latest}

case "$pkg_manager" in
  bun|npm|pnpm) ;;
  *)
    printf 'Unsupported package_manager: %s\n' "$pkg_manager" >&2
    exit 1
    ;;
esac

if [[ "$wrangler_version" == latest ]]; then
  package=wrangler
else
  package="wrangler@$wrangler_version"
fi

install_root=${WRANGLER_INSTALL_ROOT:-${RUNNER_TEMP:-$(mktemp -d)}}
install_dir="$install_root/wrangler-cli"
mkdir -p -- "$install_dir"
printf '{"private":true}\n' > "$install_dir/package.json"

case "$pkg_manager" in
  bun) bun add --cwd "$install_dir" "$package" ;;
  pnpm) pnpm --dir "$install_dir" add "$package" ;;
  npm) npm install --prefix "$install_dir" --no-audit --no-fund "$package" ;;
esac

bin_dir="$install_dir/node_modules/.bin"
if [[ ! -x "$bin_dir/wrangler" ]]; then
  printf 'Wrangler executable not found at %s after install\n' "$bin_dir/wrangler" >&2
  exit 1
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$bin_dir" >> "$GITHUB_PATH"
fi

printf 'Installed %s in %s\n' "$package" "$install_dir"
