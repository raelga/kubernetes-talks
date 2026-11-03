# Terraform: from local state to an S3 backend

A self-contained **90-minute** lab covering `init → plan → apply`, declarative changes, drift, state and locking. It requires only Terraform, AWS CLI and S3; no EC2, Kubernetes, Python, or IAM creation or modification. The [instructor guide](instructor-guide.md) includes timing, preparation and observation criteria.

**Verified in AWS Academy:** the complete live workflow succeeded with `hashicorp/awscc` 1.108.0: generated and exact bucket names, versioning, a private object and updates, drift detection/reconciliation, local → S3 migration with stable IDs and a no-change plan, AES256 state with a VersionId, concurrent exclusion using `.tflock`, the destruction guard and complete retirement. Both buckets and all state/lock versions and delete markers were removed; no trial buckets remained. AWS 5.100.0 had failed on its bucket resource because an optional Object Lock read was denied by an SCP; the official Cloud Control resource worked with the same role, without changing IAM or protections. Permissions in other Academy labs must still be checked.

## Two independent roots, two responsibilities

| Path | Resources | Initial state | State destination |
| --- | --- | --- | --- |
| `bootstrap/` | Private backend bucket, SSE-S3 encryption, disabled ACLs, public access blocking and configurable versioning | Local | **Always local**, outside Git, with a secure external backup |
| `exercise/` | Another private bucket with the same protections and the `hello.txt` object | Local | S3, only after the guided migration |
| `files/hello.txt` | Exercise object content | Not state | Version-controlled teaching file |

By default (`bucket_name = null`), names are `tfstate-<account>-<lab_id>-<12hex>` and `tfexercise-<account>-<lab_id>-<12hex>`. Each root generates its own suffix using `random_id`: 6 bytes persisted in its state. Two people with independent states get different names even when sharing an account and `lab_id`. No timestamps or `uuid()` values that change on every plan are used. With the maximum 20-character `lab_id`, names are at most 54 and 57 characters, below S3's 63-character limit. Choose a recognizable teaching identifier; you no longer need to coordinate its uniqueness.

Optionally, `bucket_name = "my-available-exact-name"` skips the suffix and uses **that exact name** in the corresponding root. It must be globally available, follow S3 rules (input validation checks basic length/syntax; AWS/the provider checks final restrictions), and differ from the other bucket. This does not adopt or import an existing bucket. Changing the name, account or identifier after creation can require replacement; `prevent_destroy` blocks backend replacement. Do not remove it to resolve an accidental change.

Always preserve state: it also contains the random suffix. Copying state **does not create an independent run**; it copies identity and makes both directories manage the same resources. Every new independent run starts with its own state; resuming uses the original state. Do not delete state to obtain another name. Get actual names from outputs for backend configuration, S3 queries and cleanup; never reconstruct them manually from account/identifier. In each root, `aws_caller_identity` and the bucket precondition compare the active account with `account_id`; the AWS provider and backend also check the expected account. AWSCC has no `allowed_account_ids`, so the precondition is necessary.

The state bucket has `prevent_destroy = true`; the exercise bucket does not, allowing reviewed removal. `awscc_s3_bucket` only deletes empty buckets and has no `force_destroy` attribute: it does not empty objects or versions automatically. Neither bucket has public ACLs, public policies or credentials in code. Backend versioning starts suspended (`Suspended`) to demonstrate a declarative change and **is enabled before using the backend**. Suspending it later does not delete previous versions and is outside this lab.

## Requirements and AWS Academy preflight

- Terraform **>= 1.10 and < 2.0**; providers `hashicorp/awscc` **>= 1.108 and < 2.0**, `hashicorp/aws` **>= 5.80 and < 6.0**, and `hashicorp/random` **>= 3.6 and < 4.0**. AWSCC manages buckets through AWS Cloud Control; AWS handles identity and S3 objects; Random preserves suffixes. Configure AWS CLI v2 with temporary lab credentials using the authorized mechanism, never in HCL files or Git.
- Open a terminal in `course/terraform/s3-state-intro` in `raelga/kubernetes-talks`. All commands below start there; `-chdir` always identifies the affected root.
- Confirm with the instructor the lab type, permitted region, credential expiry/renewal, persistence between sessions, time/budget limits and cleanup procedure. Do not assume all Academy labs allow the same operations.
- The instructor must check S3 creation/configuration permissions beforehand: tags, public access blocking, `BucketOwnerEnforced` ownership, encryption and versioning, plus inspection and reviewed deletion of exercise resources. Do not request broader permissions or create roles/policies.
- Also check AWS Cloud Control permissions and the create/read/update/delete lifecycle of `awscc_s3_bucket` with the authorized role. This resource groups bucket protections; it does not use `aws_s3_bucket`, whose optional Object Lock read failed in the AWS 5.100.0 trial. The SCP deny remains intact: do not broaden IAM, disable protections or hide permission errors. The tested role's result does not imply identical permissions in all Academy labs.
- The backend requires `s3:ListBucket` on the bucket, `s3:GetObject` and `s3:PutObject` on **the exact key** `exercise/terraform.tfstate`; and `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on **the exact key** `exercise/terraform.tfstate.tflock`. Configuring/querying versioning uses `s3:PutBucketVersioning`/`s3:GetBucketVersioning`. Inspecting versions requires `s3:ListBucketVersions`; retrieving a version requires `s3:GetObjectVersion`. Final retirement requires specific version-deletion permissions, not needed for everyday state operations.
- `sts get-caller-identity` alone is insufficient: also verify listing, writing and retrieving objects, and the lock create/read/delete cycle. The instructor guide explains the safe check; if Academy denies an operation, **stop before migrating** and resolve it with the responsible person, without disabling locking or protections.

```sh
terraform version
aws --version
aws sts get-caller-identity
```

Record the actual account ID and authorized region. `.example` files contain synthetic values, not existing resources. S3 charges for storage, versions and requests; review lab limits, Billing/Cost Explorer and available alerts. Billing data can be delayed, and a budget **does not automatically stop spending**.

## 1. Create backend infrastructure, but keep its state local

```sh
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
```

Edit `bootstrap/terraform.tfvars`: actual account, authorized region and recognizable `lab_id`. Keep `bucket_name = null` for automatic uniqueness, `enable_versioning = false` and `stage = "basics"`.

```sh
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=private-bootstrap.tfplan
terraform -chdir=bootstrap apply private-bootstrap.tfplan
terraform -chdir=bootstrap output
```

Review the name, account/region, tags and protections of `awscc_s3_bucket.state` in the plan: blocked public access, disabled ACLs, encryption and initially `Suspended` versioning; also review `prevent_destroy`. Cloud Control only allows deleting an empty bucket. No IAM or compute is created. Store **the bootstrap directory and local state** securely and persistently outside Git and this bucket; losing them does not delete the bucket, but loses its Terraform association. Never run `terraform init -migrate-state` or use an S3 backend in this root.

`fmt` normalizes HCL formatting; `validate` checks configuration and types, not permissions or costs. `init` downloads providers and generates `.terraform.lock.hcl`; `plan` queries AWS and proposes changes. Only `apply` executes the approved plan.

Now change the same `terraform.tfvars`:

```hcl
enable_versioning = true
stage             = "backend-ready"
```

```sh
terraform -chdir=bootstrap plan -out=private-bootstrap-versioning.tfplan
terraform -chdir=bootstrap apply private-bootstrap-versioning.tfplan
export AWS_REGION="us-east-1" # Replace with the actual region in both tfvars files.
export STATE_BUCKET="$(terraform -chdir=bootstrap output -raw state_bucket_name)"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

The **read-only** query must return `"Status": "Enabled"`; Terraform output does not replace this check. When first enabling versioning, AWS recommends waiting **15 minutes before writing objects** to avoid propagation issues: work through sections 2–3 meanwhile and respect this interval before the write preflight and migration. Do not continue if versioning remains suspended or the query is denied.

## 2. Apply the exercise with local state

```sh
cp exercise/terraform.tfvars.example exercise/terraform.tfvars
```

Enter the same account, region and identifier; use `demo_tag = "initial"`. **Do not copy the backend examples yet.**

```sh
terraform -chdir=exercise init
terraform -chdir=exercise validate
terraform -chdir=exercise plan -out=private-exercise.tfplan
terraform -chdir=exercise apply private-exercise.tfplan
export EXERCISE_BUCKET="$(terraform -chdir=exercise output -raw exercise_bucket_name)"
aws s3api list-objects-v2 --bucket "$EXERCISE_BUCKET" --region "$AWS_REGION"
aws s3api get-object --bucket "$EXERCISE_BUCKET" --key hello.txt --region "$AWS_REGION" exercise/private-hello.download.txt
```

Read the downloaded file: it should contain the greeting. The object is not public; an anonymous URL is not an appropriate test. Do not upload private content to the bucket or teaching file.

## 3. Changes and drift, only in the exercise

1. Edit `files/hello.txt` with another greeting and change `demo_tag = "updated"` in `exercise/terraform.tfvars`.
2. Run `terraform -chdir=exercise plan -out=private-change.tfplan`, review that the object and **exercise bucket** tag change, then run `terraform -chdir=exercise apply private-change.tfplan`. Download the object again with `get-object` to observe its content.
3. In the S3 console, select exactly `$EXERCISE_BUCKET` (never `$STATE_BUCKET`) and change only the `Demonstration` tag to `outside-terraform`. Preserve all others. Alternatively use `get-bucket-tagging` and `put-bucket-tagging` with an edited private file, remembering that `put-bucket-tagging` **replaces the entire tag set**.
4. Run `terraform -chdir=exercise plan -out=private-drift.tfplan`. It should propose restoring `Demonstration = "updated"` without recreating the bucket. Apply that plan to reconcile drift. Do not use `ignore_changes` or a state refresh to hide it.

```sh
terraform -chdir=exercise output -json > exercise/private-ids.before.json
terraform -chdir=exercise state list
terraform -chdir=exercise state show awscc_s3_bucket.exercise
terraform -chdir=exercise state show aws_s3_object.hello
```

Outputs record the bucket name/ID and object ID; in `state show awscc_s3_bucket.exercise`, `bucket_name` and `id` correspond to the same actual name. Tags are a list of `key`/`value` objects; protections are integrated in that resource, not separate resources. Use `terraform -chdir=bootstrap state show awscc_s3_bucket.state` to compare `versioning_configuration.status` with the `versioning_status` output and the read-only AWS query. Keep all state, plans, identity captures and actual configuration outside Git.

## 4. Migrate only the exercise state

Before continuing, the instructor verifies the propagation wait, `Enabled` versioning and the object/lock permissions listed in the preflight. Confirm no one else is operating this backend. Save a secure copy of the exercise's local state; it can contain sensitive information.

```sh
terraform -chdir=exercise state pull > exercise/private-before-migration.tfstate
cp exercise/backend.tf.example exercise/backend.tf
cp exercise/backend.hcl.example exercise/backend.hcl
```

Edit `exercise/backend.hcl` with the **actual name** of `$STATE_BUCKET`, region and account; preserve `key = "exercise/terraform.tfstate"`, `encrypt = true` and `use_lockfile = true`. Do not paste credentials: backend and provider independently use the authorized AWS session. Variables in `terraform.tfvars` do not configure the backend.

```sh
terraform -chdir=exercise init -migrate-state -backend-config=backend.hcl
```

Read the local-to-S3 state-copy prompt and accept only if source and destination are correct. Do not substitute `-reconfigure` for `-migrate-state`, use `-force-copy` or additional workspaces, or migrate any other lab. Resources are not recreated: only the storage location of the existing-resource record changes.

```sh
terraform -chdir=exercise output -json > exercise/private-ids.after.json
diff exercise/private-ids.before.json exercise/private-ids.after.json
terraform -chdir=exercise state list
terraform -chdir=exercise plan
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate --region "$AWS_REGION"
aws s3api list-object-versions --bucket "$STATE_BUCKET" --prefix exercise/terraform.tfstate --region "$AWS_REGION"
```

`diff` must show no differences; also compare IDs with the earlier `state show` results. The plan must show **no changes**. The S3 query must show state, `AES256` encryption and a `VersionId`. The prefix can also list lock versions; distinguish exact keys. These are criteria to observe in the account, not results already verified by this repository.

### Observe the lock without writing resource changes

1. Temporarily change `demo_tag` to `lock-observation` in the exercise tfvars.
2. Run `terraform -chdir=exercise apply` **without** `-auto-approve` and leave the approval prompt open. This process holds the lock while waiting; do not answer yet.
3. In another terminal, with the same environment variables and authorized credentials, inspect the object:

   ```sh
   aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION"
   aws s3api get-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate.tflock --region "$AWS_REGION" exercise/private-lock.json
   terraform -chdir=exercise plan -lock-timeout=5s
   ```

   The second process must report the lock, not proceed concurrently. Lock JSON contains operator identity: do not share it or commit it to Git.
4. Answer **`no`** in the first terminal, restore `demo_tag = "updated"` and repeat `plan`: no changes. Absence of the current `.tflock` object after release is normal; historical versions may persist. After an interruption, first check that no process remains active; do not delete the lock or run `force-unlock` to bypass a legitimate operation.

**Two different locks:** `exercise/terraform.tfstate.tflock` is a temporary S3 object providing mutual exclusion for **state** operations; `.terraform.lock.hcl` records **provider** versions and checksums. The latter does not lock out other operators and is committed after generation and review for each root. DynamoDB is unnecessary with `use_lockfile` and Terraform >= 1.10.

## 5. Normal completion: remove only the exercise

The state bucket **is not** the exercise bucket. Run only from `exercise`:

```sh
terraform -chdir=exercise plan -destroy -out=private-destroy.tfplan
terraform -chdir=exercise show private-destroy.tfplan
```

Review that only `awscc_s3_bucket.exercise` for the exact `$EXERCISE_BUCKET`, `aws_s3_object.hello` and the random suffix, when present, are removed; **never** `$STATE_BUCKET`. Protections are bucket attributes, not additional resources. The `tfexercise-`/`tfstate-` prefixes identify only generated names: if you used `bucket_name`, the actual output name is authoritative. Only after this review:

```sh
terraform -chdir=exercise apply private-destroy.tfplan
terraform -chdir=exercise state list
terraform -chdir=exercise plan
```

Applying a saved destruction plan is equivalent to a reviewed `destroy`; it does not launch another implicit plan. If using `terraform -chdir=exercise destroy` instead, also review its interactive plan before confirming. Do not run both. Terraform first deletes its `hello.txt` object; if someone added objects manually, Cloud Control refuses to delete the nonempty bucket: review exact objects before deleting them. Preserve the backend and bootstrap local state for the next lab. Even with no resources left, empty remote state remains a backend consumer.

## Complete and exceptional backend retirement

This is not part of normal 90-minute completion. Only a responsible operator may perform it, in an exclusive window with authorization, **after inventorying all consumers** and migrating them to another backend or destroying their resources and removing their S3 dependency as well. An empty `exercise` is insufficient; do not assume it is the only consumer.

1. Preserve secure copies of all state and configuration. For the empty exercise, use `terraform -chdir=exercise state pull > exercise/private-before-retirement.tfstate`. Replace its `backend.tf` content with:

   ```hcl
   terraform {
     backend "local" {}
   }
   ```

   Run `terraform -chdir=exercise init -migrate-state` **without** `-backend-config` and confirm the backend is now `local`. For nonempty state, accept and compare the S3 → local copy. If remote state is already empty, Terraform may neither prompt nor create a local file, and `state pull` may emit no JSON: retain the previous private copy and verify there were no managed resources and no consumer still uses S3. Migration to another approved backend is also possible. Do not retire the bucket before completing these checks.
2. Confirm the account with `aws sts get-caller-identity`, the exact name with `terraform -chdir=bootstrap output -raw state_bucket_name`, and compare the consumer inventory. Stop all concurrent operations; do not delete an active lock.
3. List and review **all pages** and keys, versions and delete markers in the exact bucket, not just the exercise prefix:

   ```sh
   aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-object-versions --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   aws s3api list-objects-v2 --bucket "$STATE_BUCKET" --region "$AWS_REGION"
   ```

4. After preserving required state and authorizing each deletion, **manually delete each reviewed version or marker** using its exact key and `VersionId`. Syntax example with placeholders you must replace, **not a ready-to-run command**:

   ```sh
   aws s3api delete-object --bucket REVIEWED_EXACT_NAME --key REVIEWED_EXACT_KEY --version-id REVIEWED_EXACT_VERSION_ID --region REVIEWED_REGION
   ```

   A version whose ID is `null` is also selected explicitly with `--version-id null`. Deleting without `VersionId` may create another marker instead of emptying the bucket. Repeat the inventory until no objects, versions or markers remain. Do not use `aws s3 rb --force`, recursive deletion, emptying scripts or lifecycle purge rules. AWSCC offers no forced emptying.
5. **Only as the final configuration change**, deliberately remove only `prevent_destroy = true` from the `lifecycle` block in `bootstrap/main.tf`; preserve the identity precondition. With local backups safe and the bucket empty, review `terraform -chdir=bootstrap plan -destroy -out=private-retire.tfplan`, inspect it with `terraform -chdir=bootstrap show private-retire.tfplan`, and apply that plan only if it matches the authorized bucket. Cloud Control refuses deletion if objects or versions remain. Never delete the entire root/configuration to bypass `prevent_destroy`: protection depends on that configuration existing.
6. Retain evidence and final local state for bootstrap and consumers according to lab policy. Do not publish them in Git or the newly retired bucket.

## Repository hygiene

Examples, code and teaching content are included; `.terraform/`, state and backups, plans, private `terraform.tfvars`, `backend.hcl`, generated `backend.tf` and `private-*` files are ignored. `.example` files are version-controlled, as are each root's `.terraform.lock.hcl` files once generated/reviewed. Ignore rules are not secure storage: credentials, state and plans need custody outside Git and a persistent directory, especially in ephemeral Academy environments. Do not migrate or modify existing Terraform labs as a consequence of this exercise.
