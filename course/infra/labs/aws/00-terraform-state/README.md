# Terraform: Create an S3 State Backend

Create a private S3 bucket, inspect it, then move its Terraform state from your machine into that bucket. The next labs reuse it.

Terraform describes infrastructure in HCL. A **provider** calls AWS APIs; a **resource** describes something to create; **state** records what Terraform manages.

## 1. Get ready

Install Terraform and clone the repository:

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/infra/labs/aws/00-terraform-state/setup.sh | bash
cd "$HOME/kubernetes-talks/course/infra/labs/aws/00-terraform-state"
```

Existing checkouts are preserved; update yours first if needed. Terraform must be on your PATH, or use `$HOME/.local/bin/terraform`.

Use your configured AWS credentials and region. Check the account, then set the lab inputs in the same terminal:

```bash
aws sts get-caller-identity
export TF_VAR_account_id="$(aws sts get-caller-identity --query Account --output text)"
export TF_VAR_lab_id="state-demo"
```

Only continue in an authorized account/region. Bucket names include your account, lab ID and a random suffix. For an exact name, optionally set `TF_VAR_bucket_name`. No tfvars file is needed.

## 2. Plan, apply and inspect

```bash
terraform init
terraform plan
terraform apply
terraform state list
terraform state show aws_s3_bucket.state
terraform output
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

Review the plan and approve the apply. Terraform creates one encrypted, versioned bucket with public access blocked. State is local for now; keep it out of Git.

To see an update, set `export TF_VAR_demo_tag="updated"`, then repeat `terraform plan` and `terraform apply`.

## 3. Move state to S3

**Wait 15 minutes after first enabling bucket versioning before writing state to it.** Stop other Terraform operations and save a private backup outside the repository and bucket:

```bash
mkdir -p "$HOME/terraform-backups"
BACKUP_DIR="$(mktemp -d "$HOME/terraform-backups/state.XXXXXX")"
terraform state pull > "$BACKUP_DIR/terraform.tfstate"
cp backend.tf.example backend.tf
terraform init -migrate-state \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=aws/terraform-state/$TF_VAR_lab_id/terraform.tfstate" \
  -backend-config="allowed_account_ids=[\"$TF_VAR_account_id\"]"
terraform plan
```

The copy enables the S3 backend; it is not another settings file to edit. Approve migration to your bucket. The final plan should show **no changes**: only state storage moved, not the bucket. Encryption and native S3 locking are already configured.

## 4. Continue with EC2

Keep this terminal and its exported variables for [EC2 basics](../01-ec2-basics/README.md). EC2 and WordPress use the same bucket with different state keys.

**Keep the bucket.** It stores its own state and the later labs' states, so destruction is protected. Application labs use `terraform destroy` without deleting this bucket. See the [instructor guide](instructor-guide.md) for resuming a session or retiring the backend.
