# Teaching the Terraform state lab

## Demo flow

Follow the [README](README.md): deploy locally, inspect state, copy state and the provider lockfile, then migrate from `remote/`.

The remote plan enables versioning in place. Apply it, compare bucket IDs, show the state object in S3, and finish with a no-change plan.

## Key points

- `local/`: private/encrypted bucket, no versioning, `prevent_destroy = false`.
- `remote/`: same bucket and resource address, S3 backend, versioning enabled, `prevent_destroy = true`.
- Migration moves state, not resources. Only use `remote/` afterward.
- The tested UPC Academy role uses `us-east-1`. `awscc_s3_bucket` avoids the standard provider's denied Object Lock metadata call; no IAM changes are needed.
- No timed wait precedes migration. AWS versioning propagation remains asynchronous after the remote apply.
- Keep state private, commit provider lockfiles, and retain this bucket for later labs.

## Troubleshooting

- New bucket or replacement proposed: stop and check the copied state, naming inputs and account.
- Access denied: check credentials and the permitted region; do not weaken bucket settings.
- Interrupted migration: inspect both states before retrying; do not force-copy blindly.
- Retiring the backend requires migrating every consumer elsewhere first, including its own state. Only then deliberately remove deletion protection and account for old object versions.
