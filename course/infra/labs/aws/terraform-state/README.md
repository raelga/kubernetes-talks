# Terraform: Create an S3 State Backend

Create one protected S3 state bucket with local state, then migrate **this same root's state into its own bucket**. The bucket is private, versioned and encrypted with AES256. No sample objects, VMs or IAM changes are needed.

- **Terraform** compares configuration with infrastructure and proposes a plan.
- A **provider** talks to an API; this root uses HashiCorp AWS and Random.
- A **resource** is an object Terraform manages, such as the S3 bucket or its versioning configuration.
- **State** records resource identities. Moving state changes its storage, not the resources.

Keep credentials, states, saved plans and private configuration out of Git. Do not copy another deployment's state or discard existing state. Preserve the generated `.terraform.lock.hcl` for reproducible provider selection.

## Setup

Install Terraform and check out the repository without changing your shell's directory or PATH:

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/infra/labs/aws/terraform-state/setup.sh | bash
```

The environment-only script installs Terraform in `$HOME/.local/bin`, clones `main` into `$HOME/kubernetes-talks` and preserves existing checkouts without pulling or resetting. If a checkout already exists, update it to the approved revision before entering the new `/aws/` path. It requires Git, curl, unzip and a SHA-256 utility. It neither initializes Terraform nor provisions infrastructure. Use `$HOME/.local/bin/terraform` instead of `terraform` below if needed.

Have AWS CLI v2 and authorized credentials available. Confirm the account, permitted region, credential expiry and workspace persistence; never put credentials in HCL. Stop on access errors rather than changing IAM or weakening protections. Storage, versions and requests cost money; billing is delayed and budget alerts do not stop spending.

```bash
cd "$HOME/kubernetes-talks/course/infra/labs/aws/terraform-state"
aws sts get-caller-identity
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: set your authorized `account_id` and `region`, a unique lowercase `lab_id`, and keep `bucket_name = null`. Default naming includes your account, lab ID and a random suffix preserved in state. An optional exact `bucket_name` must be globally available; it does not import an existing bucket. The provider rejects other accounts; region validation checks syntax, not authorization. Changing naming inputs later can request replacement, which `prevent_destroy` blocks.

## Create and inspect with local state

Do **not** copy `backend.tf.example` yet: no active backend declaration means local state.

```bash
terraform init
terraform plan -out=private-create.tfplan
terraform show private-create.tfplan
terraform apply private-create.tfplan
terraform state list
terraform state show aws_s3_bucket.state
terraform output
```

Review the plan before applying: one bucket, its versioning/encryption/public-block settings and a random suffix are expected. Never apply an unexpected replacement. Inspect the real bucket using the outputs:

```bash
STATE_BUCKET="$(terraform output -raw state_bucket_name)"
AWS_REGION="$(terraform output -raw region)"
aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$AWS_REGION"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
aws s3api get-bucket-encryption --bucket "$STATE_BUCKET" --region "$AWS_REGION"
aws s3api get-public-access-block --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

Require versioning `Enabled`, encryption `AES256` and all four public-access blocks `true`. **Wait 15 minutes after first enabling versioning before writing any objects to this bucket**, including state migration, as AWS recommends for propagation.

Optionally change only `demo_tag` to `updated`, then run `terraform plan -out=private-tag.tfplan`, review it with `terraform show private-tag.tfplan`, and apply with `terraform apply private-tag.tfplan`. Only the tag should change.

## Migrate this root's state to its own bucket

Finish the versioning wait and stop concurrent Terraform operations first. Store backups **outside both Git and this bucket**, on persistent private storage. Replace the backup path below with such a location:

```bash
BACKUP_DIR="/absolute/path/to/private-backup/terraform-state-YOUR-LAB-ID"
mkdir -p "$BACKUP_DIR"
terraform state pull > "$BACKUP_DIR/before-migration.tfstate"
terraform output -json > "$BACKUP_DIR/outputs.before.json"
cp backend.tf.example backend.tf
cp backend.hcl.example backend.hcl
```

Set `backend.hcl` to the exact bucket output, authorized account and region. Replace `YOUR-LAB-ID` in `key = "aws/terraform-state/YOUR-LAB-ID/terraform.tfstate"` with your unique identifier. Keep `encrypt = true` and `use_lockfile = true`. Backend settings are separate from provider variables and cannot reference resources or tfvars; never add credentials. Securely preserve the root's configuration and backend settings alongside the backup.

```bash
terraform init -migrate-state -backend-config=backend.hcl
terraform output -json > "$BACKUP_DIR/outputs.after.json"
diff "$BACKUP_DIR/outputs.before.json" "$BACKUP_DIR/outputs.after.json"
terraform state list
terraform state show aws_s3_bucket.state
terraform plan
aws s3api head-object --bucket "$STATE_BUCKET" --key aws/terraform-state/YOUR-LAB-ID/terraform.tfstate --region "$AWS_REGION"
```

Replace `YOUR-LAB-ID` in the final command too. Accept the migration prompt only for the intended local-to-S3 destination. Use `-migrate-state`, **not** `-reconfigure` or forced copying. Require unchanged outputs and resource IDs, a no-change plan, and a state object with `ServerSideEncryption: AES256` and a `VersionId`. Stop if Terraform proposes recreating resources.

Native S3 `.tflock` locking coordinates concurrent state operations (Terraform >= 1.10); `.terraform.lock.hcl` instead records provider versions and checksums. Do not delete active locks or disable locking.

## Next exercise and lifecycle

Continue with [EC2 basics](../ec2-basics/README.md), reusing this bucket with its independent key `aws/ec2-basics/YOUR-LAB-ID/terraform.tfstate`; WordPress uses `aws/wordpress/YOUR-LAB-ID/terraform.tfstate`. Never share keys between roots or deployments.

**Do not destroy this self-managed backend bucket while any state depends on it.** `prevent_destroy = true` and `force_destroy = false` are intentional. Normal completion leaves it available for later labs. For explicitly authorized retirement, first back up every state outside Git/S3, stop all consumers (including empty states), and migrate each elsewhere. For this root, replace the S3 declaration in `backend.tf` with:

```hcl
terraform {
  backend "local" {}
}
```

Run `terraform init -migrate-state` without `-backend-config`, and confirm unchanged IDs and a no-change plan. Only after every dependency is removed may the responsible operator authorize removal of the protection and retirement of the reviewed, empty bucket, accounting for all historical versions and delete markers. No purge or forced-empty workflow is provided.
