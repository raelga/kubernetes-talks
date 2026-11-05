# Terraform and S3: operations reference

Use the [README](README.md) for setup, the bucket-only path, backend migration, locking and exercise cleanup. This companion covers permission checks, failures and exceptional backend retirement. No IAM changes or deployments from other labs are needed.

## Permissions and preflight

- Confirm authorized identity, account, region, credential expiry, workspace persistence and cost limits. Arrange private external custody for bootstrap's local state. Never store it in its own bucket.
- Use the Terraform/provider constraints in each root's HCL. AWSCC manages buckets through Cloud Control, AWS manages identity and objects, and Random preserves naming suffixes. Each root has its own reviewed provider lockfile.
- Keep account guards: AWS `allowed_account_ids` and each AWSCC bucket's caller-identity precondition. These do not authorize a region. Confirm the region separately.
- Default `bucket_name = null` generates account + `lab_id` + 12 random hex characters persisted per root. Independent states produce independent names; copied state preserves resource identity. A non-null name is an exact override, not an import. Preserve state, use actual outputs and never remove `prevent_destroy` to resolve backend replacement.
- Confirm Cloud Control/S3 create, read, update and empty-bucket deletion permissions, including tags, AES256 encryption, `BucketOwnerEnforced`, public access blocking and versioning. Stop on restrictions; do not weaken protections or modify IAM.
- For the backend, confirm listing the exact bucket, querying versioning, reading/writing `exercise/terraform.tfstate`, and reading/writing/deleting `exercise/terraform.tfstate.tflock`. Version inspection additionally needs `ListBucketVersions`. Exercise-object access does not prove backend access.
- Require actual `Enabled` versioning and wait **15 minutes after first enabling it before any object writes**, including preflight. Do not substitute a variable or Terraform state for the AWS query.

### Controlled-scope API preflight

Run from the lab root after the propagation wait, with reviewed `STATE_BUCKET` and `AWS_REGION` and authorized credentials:

```bash
cd "$HOME/kubernetes-talks/course/infra/labs/terraform-intro"
aws sts get-caller-identity
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --prefix exercise/ --region "$AWS_REGION"
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --region "$AWS_REGION" exercise/private-preflight.download.txt
```

Use only nonsensitive content and an explicitly authorized temporary prefix; do not broaden policies for the test. Record the returned `VersionId` for exact-version retirement. Access to this object does **not** prove get/put access to the state key: confirm that exact permission scope and require real migration/read evidence using the same key in an authorized isolated backend. Never write fake state to `.tfstate`.

Test the **exact lock key only before any consumer or migration**, in an exclusive window. Confirm no Terraform processes or backend consumers exist. A 404 from `head-object` establishes no current lock; a 403 does not, so stop.

```bash
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
# Continue only after a 404 and confirmation that no consumers or processes exist.
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION" exercise/private-preflight-lock.download.txt
aws s3api delete-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
```

Require a final 404. This synthetic API test is not a Terraform lock and must never coexist with consumers. Record its object version and delete marker; they remain in a versioned bucket until authorized retirement. Normal lock operations also leave historical versions. Never disable versioning or automatically purge them.

Proceed only when exact-bucket listing/versioning, temporary-object put/get, exact-state get/put scope and the exact-lock get/put/delete cycle are established. If permissions are missing, stop before migration. Once in use, observe real locks through the [README workflow](README.md#3-observe-and-release-the-lock); only their owning process releases them. Never delete an active lock, force-unlock or use `-lock=false`.

## Verification and custody

Keep private evidence outside Git; do not publish state or sensitive identity:

| Operation | Required result |
| --- | --- |
| Create/update | Authorized account/region; private encrypted bucket; authenticated object read; reviewed content/tag changes |
| Drift | Only the exercise `Demonstration` tag restored, no replacement or protection changes |
| Backend readiness | Actual versioning `Enabled`, initial propagation wait complete, exact-scope preflight |
| Migration | Identical IDs, no-change plan, state `head-object` with `AES256` and `VersionId` |
| Locking | Second process blocked; first canceled without applying; no-change plan after restoring tfvars |
| Exercise cleanup | Exercise-only destroy plan, empty managed state and exact bucket `NoSuchBucket` |

Saved plans may contain sensitive data. Review each with `terraform show`; changed configuration needs a new plan. Preserve bootstrap configuration/local state, private backups and backend details securely. Backend initialization is separate from the provider and cannot use resource references or tfvars. Never put credentials in backend settings.

State versions support recovery; locking prevents concurrent operations. Neither replaces backups. Empty remote state still depends on its backend and must be migrated before retirement. Storage, versions and requests can continue costing money after exercise deletion; billing is delayed and budgets do not stop spending.

## Common incidents and safe responses

| Signal | Action |
| --- | --- |
| Unexpected account or account guard rejects it | Restore the authorized identity; keep provider guards and bucket preconditions. Check region independently. |
| Name unavailable | Choose an available exact override before creation, or investigate generated name/state/account. Do not import unknown buckets, delete state or bypass `prevent_destroy`. |
| Expired credentials | Renew through the authorized mechanism in the same account, then repeat the pending operation; preserve resources and state. |
| 403 on objects, locks or configuration | Review exact permission scope with the responsible operator. A 403 is not proof that an object is absent. Do not change IAM or disable protections. |
| Versioning not `Enabled` | Review plan/apply and the AWS read. Do not write or migrate during initial propagation. |
| Everything would be created after migration | Stop; check root, bucket, key, account and state copy. Do not apply to repair it. |
| Lock without an apparent process | Investigate owner and other terminals; never delete the lock or force-unlock. |
| Bucket deletion fails because it is nonempty | Inventory unexpected objects with their owner; never force-empty. |
| Workspace lost | Recover the safeguarded bootstrap copy; disk loss does not delete cloud resources. |

## Complete and exceptional backend retirement

Only an authorized responsible operator may retire the backend, in an exclusive window. Inventory **all consumers**, including empty states. Migrate each elsewhere, or destroy its resources and remove its S3 backend dependency. Never assume the exercise is the only consumer.

1. Preserve secure copies of every state and configuration. For the exercise:

   ```bash
   cd "$HOME/kubernetes-talks/course/infra/labs/terraform-intro/exercise"
   terraform state pull > private-before-retirement.tfstate
   ```

   Replace the backend declaration in `backend.tf` with:

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

   Run `terraform init -migrate-state` **without** `-backend-config`. Confirm S3 → local and compare nonempty state with the private backup. For already empty state, Terraform may neither prompt nor write a local file, and `state pull` may emit no JSON. Retain the prior private copy and verify no resources or consumers still depend on S3. Another approved backend is acceptable. Never apply a normal plan that would recreate a destroyed exercise.

2. Set `AWS_REGION` to the authorized region, confirm the account and exact backend name, and stop concurrent operations:

   ```bash
   cd ../bootstrap
   aws sts get-caller-identity
   export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
   aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-object-versions --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   ```

   Review **all pages, keys, versions and delete markers**, not only `exercise/`. Preserve required state and resolve any active lock through its owner before proceeding.

3. Authorize each deletion and manually remove each reviewed version or marker by exact key and `VersionId`. Placeholder syntax, **not ready to run**:

   ```bash
   aws s3api delete-object --bucket REVIEWED_EXACT_NAME --key REVIEWED_EXACT_KEY --version-id REVIEWED_EXACT_VERSION_ID --region REVIEWED_REGION
   ```

   Explicitly use `--version-id null` for a null version. Omitting the version ID can create another delete marker. Repeat inventory until no objects, versions or markers remain. Never use recursive deletion, `aws s3 rb --force`, emptying scripts or lifecycle purge rules. AWSCC cannot force-empty buckets.

4. Only after all dependencies are removed, backups secured and the exact bucket confirmed empty, make the deliberate authorized retirement change: remove only `prevent_destroy = true` from the bucket's `lifecycle` block in `bootstrap/main.tf`. Preserve the identity precondition and all other configuration. This is not a workaround for replacement or an apply failure; never delete configuration to bypass the guard. From `bootstrap/`:

   ```bash
   terraform plan -destroy -out=private-retire.tfplan
   terraform show private-retire.tfplan
   terraform apply private-retire.tfplan
   terraform state list
   aws s3api get-bucket-location --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   ```

   Apply only the reviewed plan for the exact authorized backend. Require empty managed state and `NoSuchBucket`; Cloud Control refuses deletion if content remains.

5. Retain final local states and required evidence according to your retention policy, outside Git and the retired bucket.
