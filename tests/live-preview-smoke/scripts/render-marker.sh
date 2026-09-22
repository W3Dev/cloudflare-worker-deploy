#!/usr/bin/env bash

set -Eeuo pipefail

fixture_dir=${1:?fixture directory is required}
version=${2:?smoke version is required}

case "$version" in
  one|two) ;;
  *)
    printf 'Smoke version must be one or two\n' >&2
    exit 1
    ;;
esac

cat > "$fixture_dir/src/index.js" <<EOF
export default {
  async fetch() {
    return new Response("SMOKE_VERSION=$version\\n", {
      headers: { "content-type": "text/plain; charset=utf-8" },
    });
  },
};
EOF
