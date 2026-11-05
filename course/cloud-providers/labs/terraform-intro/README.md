# Terraform: S3 buckets and state

Create a private S3 bucket, update it and remove it with Terraform. The optional backend workflow adds a second bucket and migrates the exercise state to S3. No VMs, Kubernetes or IAM changes are needed.

| Root | Resources | State |
| --- | --- | --- |
| `exercise/` | Private bucket and `hello.txt` | Local, optionally migrated to S3 |
| `bootstrap/` | Protected state bucket | Always local; back up outside Git and the bucket |

Configuration describes desired resources; state records which resources Terraform manages. Never copy another run's state to create an independent deployment. Keep credentials, states, plans, private tfvars, backend settings and real captures outside Git. Reviewed `.terraform.lock.hcl` files may be committed.

## Get ready

Install the tools and clone the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/cloud-providers/labs/terraform-intro/bootstrap.sh | bash
```

The script installs Terraform in `$HOME/.local/bin` and clones `main` into `$HOME/kubernetes-talks`; existing checkouts are untouched. It does not change directory, configure AWS or deploy resources. It requires Git, curl, unzip and a SHA-256 utility. If `terraform` is not already discoverable, use `$HOME/.local/bin/terraform` in place of `terraform` below.

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro"
terraform version
aws --version
aws sts get-caller-identity
```

Use AWS CLI v2 and Terraform compatible with the root's HCL constraints; S3 lockfiles require Terraform >= 1.10. Obtain authorized credentials and confirm the account, region, expiry, workspace persistence and spending limits. Never put credentials in configuration or Git. Account guards do not authorize a region. Identity alone does not prove API access: review [permissions and preflight](instructor-guide.md#permissions-and-preflight). Stop on access errors; do not change IAM or weaken protections.

Storage, versions and requests cost money. Billing is delayed, and budget alerts do not stop spending.

## Quick path: one bucket with local state

Use a fresh exercise root with no active backend configuration. Skip `bootstrap/`, backend files and migration.

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro/exercise"
cp terraform.tfvars.example terraform.tfvars
```

Set your authorized account/region, a recognizable `lab_id`, `bucket_name = null` and `demo_tag = "initial"`. Default names include the account, lab ID and a state-persisted random suffix. An optional non-null `bucket_name` is an exact, globally available name, not an import; it must differ from the backend bucket. Changing names, account or lab ID can require replacement. Preserve state and never bypass backend `prevent_destroy` to resolve replacement.

```bash
export AWS_REGION="us-east-1" # Replace with the authorized region in your tfvars.
terraform init
terraform plan -out=private-exercise.tfplan
terraform show private-exercise.tfplan
terraform apply private-exercise.tfplan
export EXERCISE_BUCKET="$(terraform output -raw exercise_bucket_name)"
aws s3api get-object --bucket "$EXERCISE_BUCKET" --key hello.txt --region "$AWS_REGION" private-hello.download.txt
cat private-hello.download.txt
```

Review every saved plan before applying: only the private encrypted exercise bucket, object and random suffix belong here. Read the object with credentials; anonymous access is denied. Use nonsensitive example content only.

1. Edit `../files/hello.txt` and set `demo_tag = "updated"` in `terraform.tfvars`.
2. Plan, review and apply; download the object again:

   ```bash
   terraform plan -out=private-change.tfplan
   terraform show private-change.tfplan
   terraform apply private-change.tfplan
   aws s3api get-object --bucket "$EXERCISE_BUCKET" --key hello.txt --region "$AWS_REGION" private-hello.download.txt
   cat private-hello.download.txt
   terraform plan # Expect no changes.
   ```

3. Optionally observe drift: in the S3 console change only the exercise bucket's `Demonstration` tag to `outside-terraform`, preserving all other tags. Review `terraform plan -out=private-drift.tfplan`; it must restore the tag without replacing the bucket. Apply with `terraform apply private-drift.tfplan`. Never change privacy controls or use `ignore_changes` to hide drift.
4. Either continue to the optional backend workflow or [remove only the exercise](#remove-only-the-exercise).

## Optional backend workflow

### 1. Create the backend with separate local state

The exercise must already exist with local state. From any directory:

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro/bootstrap"
cp terraform.tfvars.example terraform.tfvars
```

Set the same authorized account/region and `lab_id`; keep `bucket_name = null`, `enable_versioning = false` and `stage = "basics"`. Use outputs, never reconstructed bucket names.

```bash
terraform init
terraform validate
terraform plan -out=private-bootstrap.tfplan
terraform show private-bootstrap.tfplan
terraform apply private-bootstrap.tfplan
terraform output
```

Confirm the exact account, region and private encrypted bucket. Validation checks configuration, not permissions or costs. Changed configuration requires a new plan. Securely back up this root and its local state outside Git and the bucket. **Never migrate bootstrap's state into its own bucket.**

Set `enable_versioning = true` and `stage = "backend-ready"` in the same tfvars:

```bash
terraform plan -out=private-versioning.tfplan
terraform show private-versioning.tfplan
terraform apply private-versioning.tfplan
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

Require `"Status": "Enabled"`. **Wait 15 minutes after first enabling versioning before writing any objects to this bucket**, including preflight objects. Then complete the [controlled-scope preflight](instructor-guide.md#controlled-scope-api-preflight). Stop if exact state/lock permissions are unconfirmed.

### 2. Migrate only the exercise state

Ensure no other operation uses this state. Return to the exercise, preserve its IDs and a private backup, then enable its backend:

```bash
cd ../exercise
terraform output -json > private-ids.before.json
terraform state list
terraform state pull > private-before-migration.tfstate
cp backend.tf.example backend.tf
cp backend.hcl.example backend.hcl
```

Set the actual `$STATE_BUCKET`, account and region in `backend.hcl`. Preserve `key = "exercise/terraform.tfstate"`, `encrypt = true` and `use_lockfile = true`. Backend configuration is separate from tfvars and cannot use provider variables or resource references. Do not add credentials.

```bash
terraform init -migrate-state -backend-config=backend.hcl
terraform output -json > private-ids.after.json
diff private-ids.before.json private-ids.after.json
terraform plan
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate --region "$AWS_REGION"
```

Accept migration only for the intended source/destination. Never use `-reconfigure` or force copying. Require unchanged IDs, a no-change plan, and an S3 state object with `AES256` encryption and a `VersionId`. Migration moves the record, not the resources.

### 3. Observe and release the lock

Temporarily set `demo_tag = "lock-observation"` and run `terraform apply`. Leave the approval prompt open; **do not approve**. In a second terminal with the same authorized credentials:

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro/exercise"
terraform plan -lock-timeout=5s
```

The second operation must fail because the first holds the lock. Answer `no` in the first terminal, restore `demo_tag = "updated"` and run `terraform plan`: expect no changes. The owning process releases the lock; never delete an active lock, force-unlock or use `-lock=false`.

The S3 `.tflock` provides mutual exclusion. `.terraform.lock.hcl` pins provider versions/checksums, not concurrent operations. Versioning supports recovery, not locking; no DynamoDB is needed.

## Remove only the exercise

From `exercise/`:

```bash
terraform plan -destroy -out=private-destroy.tfplan
terraform show private-destroy.tfplan
terraform apply private-destroy.tfplan
terraform state list
aws s3api get-bucket-location --bucket "$EXERCISE_BUCKET" --region "$AWS_REGION"
```

Apply only if the plan removes the exact exercise bucket, `hello.txt` and random suffix—never the backend bucket. Require empty managed state **and `NoSuchBucket`** from the exact-name AWS check. Access denied is not proof of deletion. Investigate unexpected objects with their owner; never bulk-empty buckets. Retain state until cleanup is verified. A subsequent normal plan proposes recreation: do not apply it.

If you used S3 state, keep the backend and bootstrap's local state: **an empty remote state is still a backend consumer**. Full retirement requires the separate [authorized retirement procedure](instructor-guide.md#complete-and-exceptional-backend-retirement). See [safe error responses](instructor-guide.md#common-incidents-and-safe-responses) if an operation fails.
