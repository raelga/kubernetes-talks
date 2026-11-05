# Teaching the Terraform state lab

## Demo flow

Follow the [README](README.md): create and inspect the bucket locally, wait 15 minutes after enabling versioning, copy state and provider lockfile, then migrate. Compare outputs, the no-change plan and the S3 object.

## Key points

- Providers call AWS APIs; resources describe infrastructure; state records resource identities. Migration moves state, not the bucket.
- Keep the same account, region and inputs. Copying the lockfile preserves provider selection; never copy `.terraform/`.
- Use only `remote/` afterward. The original local state is a stale backup, not a second working stack. Keep state private and out of Git.
- Each lab has a fixed state key: one deployment per lab per bucket. Encryption, versioning and native locking protect state.
- Keep the bucket for later labs. To retire it, stop consumers, privately back up all states and migrate them elsewhere, including this bucket's own state, before deliberately removing deletion protection. Account for old object versions; do not force-empty it.

## Troubleshooting

- Unexpected creates or replacements: stop and check copied state, account, inputs and backend key.
- Access denied: correct credentials or permissions; do not weaken bucket protections.
- Interrupted migration: inspect source and destination before retrying; never discard state or force-copy blindly.
