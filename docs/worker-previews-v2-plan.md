# Worker Previews v2 implementation plan

Status: implementation in progress on `worker-previews-v2`.

## Contract verified before implementation

- Wrangler 4.135.0 exposes `wrangler preview [script] --name <name> --json`.
- The JSON result is an object with `preview` and `deployment` resources.
- Preview URLs are returned in `preview.urls`; unique deployment URLs are returned in `deployment.urls`.
- Cleanup is `wrangler preview delete --name <name> --skip-confirmation`.
- Wrangler's preview config is read from the branch's `previews` block and supports preview-safe variables, bindings, secrets configuration, observability, and selective resource isolation.

## Delivery checklist

- [x] Add explicit, validated preview naming and safe event context handling.
- [x] Require Wrangler >= 4.135.0 for preview mode and preserve production deployment behavior.
- [x] Use structured preview JSON, validate its envelope, and map stable/unique URLs to documented outputs.
- [x] Make teardown delete the named Preview and fail on command errors.
- [x] Add mocked command tests for preview, malformed output, failure, teardown, production, and unsafe input cases.
- [x] Add action metadata/YAML/shell validation in CI.
- [x] Update README and maintenance notes for v1 to v2 migration, config/secrets/isolation, custom domains, and debugging.
- [ ] Run checks, inspect the final diff, and commit with normal hooks. Do not push or tag in this phase.
