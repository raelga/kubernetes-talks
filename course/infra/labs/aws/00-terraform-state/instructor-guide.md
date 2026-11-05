# Teaching the Terraform state lab

Use the [README](README.md) for the commands. The story is simple: **create a bucket locally, move its state to S3, prove nothing was recreated**.

## Before you start

- Check the AWS account and configured region. Automatic account discovery does not authorize access.
- Start with fresh `local/` and `remote/` working directories, not another deployment's state.
- Use the same AWS environment and input overrides throughout.

## What to show

1. In `local/`, compare the plan with the bucket created by apply.
2. Open `terraform.tfstate` privately and identify the bucket ID. Never commit or share it.
3. Wait 15 minutes after enabling versioning before migrating state.
4. Copy `terraform.tfstate` and the provider lockfile into `remote/`, then change folders. The original local state remains as the backup.
5. Run migration, compare outputs, and show the no-change plan and S3 state object.

The copied state supplies the existing resource identities. Without it, Terraform would propose another bucket. The copied provider lockfile keeps provider selection consistent; do not copy `.terraform/`.

## Questions worth asking

- Did the bucket move, or only the state? Only the state.
- Why does `remote/` need the old state? To recognize the existing bucket.
- Why separate state keys for later labs? Each stack owns different resources.

## If something goes wrong

- **New resources or replacement proposed:** stop. Check state, inputs, account and backend key.
- **Access denied:** fix the authorized credentials or permissions; do not weaken bucket protections.
- **Interrupted migration:** inspect both states and the destination before retrying; never force-copy or discard state.
- **Previously initialized with an older state key:** deliberately migrate with `terraform init -migrate-state` before adopting the fixed key; do not use `-reconfigure` to silently switch states.

## After the demo

Use only `remote/`. The original `local/` state is now a stale backup. Keep both folders' resource definitions aligned when changing the lab.

Leave the bucket for the later labs. To retire it, stop all consumers, back up every state privately, and migrate those states elsewhere first. This bucket's own state must also move back to a local backend before deletion protection can be deliberately removed. Account for old object versions; do not force-empty the bucket.
