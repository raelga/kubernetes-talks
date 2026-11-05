# Terraform and S3: instructor pointers

The [README](README.md) is the complete learner path: create one bucket locally, inspect it, then migrate the same root's state to that bucket. `setup.sh` prepares tools and checkout only; there is no separate infrastructure bootstrap root.

- Use an authorized account and region with credentials valid for the session. Preserve the AWS provider's `allowed_account_ids` guard. Region syntax validation is not region authorization.
- Confirm permission to create/read/tag the bucket and manage its versioning, AES256 encryption and public access block. Backend access additionally needs bucket listing, state get/put, and lockfile get/put/delete on the exact authorized keys. Stop on permission restrictions; do not change IAM or weaken protections.
- Require actual AWS versioning `Enabled` and the 15-minute initial propagation wait before migration. Keep persistent private state/configuration backups outside Git and the managed bucket.
- Migration success means unchanged output values and resource IDs, a no-change plan, and `head-object` evidence of AES256 and a version ID at the exact intro key. A plan proposing recreation means stop and investigate root, account, bucket, key and state—not apply.
- A globally unavailable name is not a reason to import an unknown bucket or remove `prevent_destroy`. Credential expiry is not a reason to discard state. A 403 does not prove that a bucket or object is absent.
- Other labs reuse `state_bucket_name`, never the intro state key. Keep native S3 locking enabled; only the owning operation releases an active lock.
- Leave the bucket in place for subsequent exercises. Self-hosted state makes deletion unsafe until every consumer has stopped and migrated away, including this root back to local state. Retirement requires explicit authorization, external backups and review of all object versions/delete markers; never force-empty or provide a bulk purge script.

No provider/API execution is implied by these source instructions. Account verification and actual deployment require a separately authorized run.
