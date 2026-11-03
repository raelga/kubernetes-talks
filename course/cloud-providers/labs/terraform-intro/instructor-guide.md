# Instructor guide — Terraform and S3 state in 90 minutes

## Scope and observable outcomes

An independent, reusable introductory lab, without a date or session number. All required work uses Terraform and S3: no EC2 or other labs are deployed, Python is unnecessary, and IAM is neither created nor modified. This does not replace the cloud labs or migrate their state.

By the end, learners should explain and demonstrate:

- Two independent roots: bootstrap with persistent local state, and the exercise initially local, then remote.
- A tag change and backend versioning enabled before use; a read-only AWS query returning `Enabled`.
- A declarative `hello.txt` update, drift in an **exercise** tag and reconciliation without bucket recreation.
- Identical resource IDs before and after `init -migrate-state`, versioned remote state and a no-change plan.
- A `.tflock` while an operation awaits approval, and a second process refusing to operate concurrently.
- The difference between the state lock and `.terraform.lock.hcl`, and an exercise-only destruction plan that preserves the backend.

**Live verification completed in Academy:** the bucket workflow, generated name and exact override, versioning, object and update, drift/reconciliation, migration with stable IDs, encrypted/versioned remote state, concurrent locking, cancellation without applying changes and full cleanup. Verification also confirmed that `prevent_destroy` prevents accidental backend retirement. The official `hashicorp/awscc` 1.108.0 provider resolved the incompatibility between the AWS 5.100.0 resource's optional Object Lock read and the SCP, without changing IAM or protections. No trial buckets remain. This establishes the tested role's behavior, not universal permissions across Academy environments.

## Preparation before the 90 minutes

1. Confirm the specific Academy lab: access, temporary credential delivery and expiry, authorized region, workspace/resource persistence, time/cost limits and cleanup policy. Do not assume a universal lab type or persistent disk. Prepare private external custody for bootstrap local state.
2. Provide Terraform >= 1.10 and < 2, AWS CLI v2, and download access for AWSCC >= 1.108 and < 2, AWS >= 5.80 and < 6, and Random >= 3.6 and < 4. AWSCC manages buckets through Cloud Control; AWS manages identity and objects; Random preserves suffixes. Do not change providers in other examples. The two roots have separate provider locks; generated, reviewed lockfiles may be committed, never state.
3. Check lab identity and account/region. `allowed_account_ids` guards against a different account, not an unauthorized region. By default, `bucket_name = null` generates account + `lab_id` + 12 random hex characters persisted per root; independent states with identical parameters generate different names. Maximum name lengths are 54/57 characters. Do not share/copy states between learners: copying state preserves identity, not a separate lab. Keeping state preserves the suffix on resumption. A non-null `bucket_name` uses the exact name without randomness: check global availability and S3 rules; do not interpret it as adoption/import. Changing the name may replace the resource; `prevent_destroy` must block backend replacement, not be removed to resolve it. Always use actual outputs for backend configuration, APIs and retirement, never reconstructed names.
4. Rehearse the entire lifecycle and preservation/retirement procedure using your own instructor identifier. Expected tags are `Project`, `LabId`, `ManagedBy`, `Purpose` and `Stage` or `Demonstration`; changes/demos must not touch privacy protections.
5. Verify AWS Cloud Control and S3 API permissions beforehand for creating, reading, updating and deleting empty buckets, tags, AES256 encryption, `BucketOwnerEnforced` ownership, public access blocking and versioning. Protections are integrated in `awscc_s3_bucket`; the old AWS resource's optional Object Lock read is not used. If Academy restricts these operations, resolve this with the lab owner: **do not** weaken protections, add IAM or require an alternative deployment.
6. Check object and lock permissions using actual credentials and **authorized prefixes**. For the backend: list the bucket, read/write the state key; read/write/delete the `.tflock` key; query versioning. Version inspection also requires `ListBucketVersions`. Successful `get-object` in the exercise bucket does not establish backend permissions.
7. Reserve **15 minutes from first enabling versioning until writing objects** in that bucket. The schedule uses this interval for the exercise and drift. If configuration takes longer or incidents occur, finish later without skipping preflight or claiming the work is already verified.

### Controlled-scope API preflight

Run these preflight commands from `course/cloud-providers/labs/terraform-intro`, not from either Terraform subdirectory. The learner README explicitly changes directories as the exercise progresses.

Before allowing migration, check `aws sts get-caller-identity`, `get-bucket-versioning` and `list-objects-v2` on the actual backend. The versioning query must show `Enabled`; run it after `apply`, rather than relying only on a variable or Terraform state.

To rehearse `PutObject`/`GetObject`/`ListBucket` without introducing a fake state file, use a **nonsensitive test object** in an authorized temporary prefix, such as `exercise/preflight.txt`. Permissions for this prefix must be explicitly available; do not broaden policies to perform the trial. Permissions on this key alone do not establish permissions on `exercise/terraform.tfstate`: also check the exact authorized scope and complete an instructor rehearsal of real migration/reading using that same key in the instructor's test backend. Do not write a test file to the `.tfstate` key.

API example for the instructor rehearsal, after the propagation wait and with reviewed `STATE_BUCKET`/`AWS_REGION`:

```sh
aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --prefix exercise/ --region "$AWS_REGION"
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/preflight.txt --region "$AWS_REGION" exercise/private-preflight.download.txt
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

Record the test object's `VersionId`. Delete it at final retirement manually using the exact reviewed version, never recursive emptying; it may be retained until authorized backend retirement.

To check **the exact lock key**, before any consumer/migration and in an exclusive window, confirm with `head-object` that no current lock exists and that no Terraform processes are active. Only then may the instructor test the API cycle with nonsensitive content at `exercise/terraform.tfstate.tflock`: this is not a real Terraform lock and must never coexist with a consumer. Do not run this test on a backend already in use.

```sh
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
# Continue ONLY if the responsible operator confirms no consumers and the response is 404.
# A 403 does not establish that the key is absent: stop the trial.
aws s3api put-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --body files/hello.txt --server-side-encryption AES256 --region "$AWS_REGION"
aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION" exercise/private-preflight-lock.download.txt
aws s3api delete-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
```

The final `head-object` must return 404. This `DeleteObject` test creates a marker in a versioned bucket; the test version and marker remain visible in `list-object-versions` and must be reviewed for manual retirement. Normal backend operation also leaves historical lock versions. The goal is not automatic version deletion or disabling versioning. Distinguish this controlled preliminary test from later observation of the **real** lock, which is only read and is released by its owning Terraform process.

Preflight acceptance requires: listing and querying versioning of the exact bucket, writing/retrieving the object, confirmed get/put scope for the state key, the `.tflock` get/put/delete cycle, and an instructor migration rehearsal without changing IAM permissions. If any permission is missing, stop before learner migration. Never use `-lock=false`, delete active locks or expose credentials to complete a demo.

## 90-minute sequence

| Minutes | Activity | Evidence / instructor intervention |
| --- | --- | --- |
| 0–10 | Declarative model, identity, region, credentials and costs; copy/edit tfvars | Expected account and personal `lab_id`; locate both roots and distinguish state from resources. Recall billing delays and that budgets do not stop spending. |
| 10–25 | `bootstrap init`, `plan`, review and `apply`; change `stage` and enable versioning with a second plan/apply | Privacy, disabled ACLs, SSE-S3, `prevent_destroy` and empty-bucket-only deletion; query `get-bucket-versioning = Enabled`. Record activation time and do not write yet. |
| 25–40 | Exercise with local state, private object reading, greeting and tag changes | A distinct second bucket; `source_hash` detects content; record IDs. This activity covers the backend propagation interval. |
| 40–50 | Drift only in the exercise's `Demonstration` tag and reconciliation | Plan restores the declared tag without recreating the bucket or modifying the backend. Complete backend preflight after the wait if not already completed. |
| 50–65 | Secure backup, examples → active backend, actual configuration and `init -migrate-state` | Confirm local → S3 copy; identical IDs; encrypted state with VersionId; no-change `plan`. Bootstrap remains local. |
| 65–80 | Interactive `apply` awaiting approval, read `.tflock`, second plan blocked; cancel and revert tfvars | Observe real lock and release by its owner; distinguish provider lockfile. Repeat no-change plan. |
| 80–90 | Review and apply **exercise-only** destruction plan, recap and custody | No `tfstate-…` in destruction; empty remote state, preserved backend and stored local bootstrap. Complete retirement is outside normal completion. |

Use the [learner README](README.md) as the command sequence. If a wait, expired credentials or a restriction prevents completion, record the actual stopping point and do not mark remaining steps verified. Do not turn safety steps into optional extensions to meet the clock.

## Explanation points

- **State is not configuration:** it maps addresses to actual resources. Backend migration moves that record; it does not `import`, rename buckets or change IDs. Do not delete state to “start over”.
- **Bootstrap is not managed from its own bucket:** this avoids a circular custody dependency. Its backend is explicitly local and requires preservation outside Git and the bucket itself. Do not run `init -migrate-state` in `bootstrap`.
- **Saved plan:** it contains decisions and may contain sensitive data. Review `terraform show` and apply only the correct root's plan. Do not upload plans, state, tfvars or actual backend configuration.
- **Drift:** use only the exercise's `Demonstration` tag. Do not change encryption, permissions or versioning for a drift demo. `put-bucket-tagging` replaces all tags; prefer the console for a single change or review the full set in a private file.
- **Versioning and locking solve different problems:** versions support recovery; `.tflock` provides mutual exclusion. Locking does not replace backups, and versioning does not prevent concurrent writes.
- **Provider lock:** `.terraform.lock.hcl` pins selection/checksums and is committed after review. It neither contains nor replaces the remote lock. `use_lockfile = true` requires Terraform >= 1.10 and S3 permissions, not DynamoDB.
- **Credentials:** the backend initializes before the provider and has its own configuration; its block cannot use `var.region`, `var.account_id` or resource references. Use the authorized temporary credential chain, not secrets in `backend.hcl` or shared commands.
- **Cost and cleanup:** version storage and requests still exist after exercise destruction. AWSCC has no `force_destroy`: deletion requires an empty bucket; never propose automatic emptying as a quick fix.

## Common incidents and safe responses

| Signal | Action |
| --- | --- |
| Unexpected account / identity precondition or `allowed_account_ids` rejects it | Review temporary session and actual account; do not remove the guard. AWSCC does not support `allowed_account_ids`: each bucket compares `aws_caller_identity.current.account_id` with the expected account through a precondition. |
| S3 name unavailable before creation | For an optional exact name, choose an available name of your own before creating; do not import an unknown bucket. With a generated name, investigate account/name/state before acting, without deleting state or removing `prevent_destroy`. |
| Expired credentials | Renew through the Academy mechanism, restore the same account and repeat the pending operation; do not reconstruct resources or state. |
| 403 on objects/lock/configuration | Review scope with the responsible person; distinguish 403 from a missing key. Do not alter IAM or disable locking/protections. |
| Versioning not `Enabled` | Review plan/apply and actual read; do not migrate. Do not write during the initial propagation interval. |
| Plan proposes creating everything after migration | Stop: review root, bucket, key, account and state copy. Do not apply to “fix it”. |
| Lock without an apparent process | Investigate owner and other terminals before any recovery. Do not delete `.tflock` or use `force-unlock` in a demo. |
| Exercise destruction fails because bucket is nonempty | Inventory additional objects and review with their owner; never force-empty. |
| Ephemeral workspace lost | Recover the safeguarded bootstrap copy; do not assume resources disappeared with the disk. |

## Minimum evidence and completion

Without publishing state or sensitive identity, compare during the session: tool versions, correct account/region, actual `Enabled` versioning, unchanged bucket/object IDs before/after, state `head-object` with encryption and version, temporary real lock, final no-change plan and exercise-only destroy plan. Private captures are not committed to Git.

Full backend retirement is outside normal class completion. Follow the separate authorized procedure below; do not retire it just because the exercise state is empty.

Optional extensions, not requirements: recover a state version only in an isolated, planned instructor environment, or compare other backends. Do not add EC2, IAM, deployments from other labs or mass migrations to this introduction.

## Complete and exceptional backend retirement

Only a responsible operator may retire the backend, in an exclusive window with authorization. First inventory **all consumers**: migrate them elsewhere, or destroy their resources and remove their S3 backend dependency. Empty exercise state is still a consumer; do not assume it is the only one.

1. Preserve secure copies of every state and configuration. For the exercise:

   ```bash
   cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro/exercise"
   terraform state pull > private-before-retirement.tfstate
   ```

   Replace the backend declaration in `backend.tf` with:

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

   Run `terraform init -migrate-state` **without** `-backend-config`. Confirm the move from S3 to local and compare any nonempty state. For already empty state, Terraform may neither prompt nor write a local file, and `state pull` may emit no JSON. Retain the prior private copy; verify that no resources or consumers still depend on S3. Another approved backend is also acceptable.

2. Select the authorized region in `AWS_REGION`, confirm the account and exact backend name, and stop concurrent operations:

   ```bash
   cd ../bootstrap
   aws sts get-caller-identity
   export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
   aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-object-versions --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   ```

   Review **all pages, keys, versions and delete markers**, not only the exercise prefix. Never delete an active lock.

3. After preserving required state and authorizing each deletion, manually delete each reviewed version or marker by its exact key and `VersionId`. This is placeholder syntax, **not a ready-to-run command**:

   ```bash
   aws s3api delete-object --bucket REVIEWED_EXACT_NAME --key REVIEWED_EXACT_KEY --version-id REVIEWED_EXACT_VERSION_ID --region REVIEWED_REGION
   ```

   Explicitly use `--version-id null` for a null version. A deletion without a version ID can create another marker instead of emptying the bucket. Repeat the inventory until no objects, versions or markers remain. Do not use recursive deletion, `aws s3 rb --force`, emptying scripts or lifecycle purge rules. AWSCC has no forced-emptying option.

4. Only as the last configuration change, deliberately remove just `prevent_destroy = true` from the bucket's `lifecycle` block in `bootstrap/main.tf`. Preserve the identity precondition and the rest of the configuration. From `bootstrap/`:

   ```bash
   terraform plan -destroy -out=private-retire.tfplan
   terraform show private-retire.tfplan
   ```

   Apply with `terraform apply private-retire.tfplan` only after confirming the exact authorized bucket, secure backups and an empty bucket. Cloud Control refuses deletion when content remains. Never delete configuration to bypass `prevent_destroy`.

5. Retain final local states and evidence according to lab policy, outside Git and the retired bucket.
