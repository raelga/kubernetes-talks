# Terraform: Create an S3 State Backend

Create one S3 bucket using local state, then move its state into that bucket. The next labs reuse it.

```text
local/   Same resources, local state
remote/  Same resources, S3 backend
```

Both folders contain complete, fixed Terraform configurations. No `.tf` editing is needed. A **provider** calls AWS APIs; **resources** describe infrastructure; **state** records what Terraform manages.

## 1. Get ready

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/infra/labs/aws/00-terraform-state/setup.sh | bash
cd "$HOME/kubernetes-talks/course/infra/labs/aws/00-terraform-state/local"
aws sts get-caller-identity
```

Use your configured AWS account and region. Existing checkouts are preserved; update yours first if needed. Terraform must be on your PATH, or use `$HOME/.local/bin/terraform`.

The lab ID defaults to `terraform-state`. Bucket names include your account and a random suffix. Optionally override `TF_VAR_lab_id` or `TF_VAR_bucket_name`; keep the same inputs and AWS environment across both folders. No tfvars files are needed.

## 2. Deploy locally

```bash
terraform init
terraform plan
terraform apply
terraform state list
terraform state show aws_s3_bucket.state
terraform output
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

Review and approve the apply. Terraform creates one encrypted, versioned bucket with public access blocked. State is in `local/terraform.tfstate`; keep it out of Git.

## 3. Change folders and migrate

**Wait 15 minutes after first enabling bucket versioning before writing state to it.** Stop other Terraform operations. Start with a fresh `remote/` directory without another deployment's state or initialized backend.

From `local/`, copy the original state and provider lockfile, then change folders:

```bash
cp terraform.tfstate ../remote/terraform.tfstate
cp .terraform.lock.hcl ../remote/.terraform.lock.hcl
cd ../remote
```

The original state stays in `local/` as your backup. The copy supplies the migration source; the provider lockfile keeps provider versions identical. Do not copy `.terraform/` or commit state.

```bash
STATE_KEY="aws/terraform-state/${TF_VAR_lab_id:-terraform-state}/terraform.tfstate"
terraform init -migrate-state \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=$STATE_KEY"
```

Approve migration from local state to your bucket. Encryption and native S3 locking are already declared in `remote/backend.tf`. **Do not apply `remote/` before migrating:** that would propose a second deployment.

## 4. Verify the migration

```bash
terraform output
terraform plan
aws s3api head-object --bucket "$STATE_BUCKET" --key "$STATE_KEY" \
  --query '{Encryption:ServerSideEncryption,Version:VersionId}'
```

The bucket name and ARN should match the outputs shown in `local/`. Expect a **no-change plan** and an S3 state object with `AES256` encryption and a version ID. Only state storage moved.

**Use only `remote/` from now on.** The old local state is a stale backup, not another active stack. Keep both roots' resource definitions aligned when maintaining this lab.

## 5. Continue with EC2

Proceed to [EC2 basics](../01-ec2-basics/README.md). EC2 and WordPress read the bucket output from `remote/` and use different state keys.

**Keep the bucket.** It stores its own state and the later labs' states, so destruction is protected. Application cleanup uses `terraform destroy` without deleting this bucket. See the [instructor guide](instructor-guide.md) for resuming or retiring the backend.
