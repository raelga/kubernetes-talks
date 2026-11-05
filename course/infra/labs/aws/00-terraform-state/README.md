# Terraform: Create an S3 State Backend

Create one S3 bucket locally, then move its Terraform state into that bucket. The next labs reuse it.

- `local/`: bucket configuration with local state.
- `remote/`: the same resources with the S3 backend already configured.

No `.tf` editing or settings files are needed. Use the same terminal, configured AWS account and region throughout.

## 1. Get ready

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/infra/labs/aws/00-terraform-state/setup.sh | bash
cd "$HOME/kubernetes-talks/course/infra/labs/aws/00-terraform-state/local"
aws sts get-caller-identity
```

Update an existing checkout first if needed. Terraform must be on your PATH, or use `$HOME/.local/bin/terraform`.

## 2. Create and inspect the bucket

```bash
terraform init
terraform plan
terraform apply
terraform state list
terraform state show aws_s3_bucket.state
terraform output
STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

Review and approve the apply. The bucket is private, encrypted and versioned; its name includes your account and a random suffix. State is now in `local/terraform.tfstate`.

A **provider** calls AWS APIs, **resources** describe infrastructure, and **state** records what Terraform manages. To use an exact bucket name instead, optionally set `TF_VAR_bucket_name` before the first plan; keep that setting through migration.

## 3. Move state to S3

**Wait 15 minutes after first enabling bucket versioning.** With no other Terraform operation running, copy the state and provider lockfile, then change folders:

```bash
cp terraform.tfstate ../remote/terraform.tfstate
cp .terraform.lock.hcl ../remote/.terraform.lock.hcl
cd ../remote
terraform init -migrate-state -backend-config="bucket=$STATE_BUCKET"
```

Approve the migration. The original state stays in `local/` as a backup. The provider lockfile keeps both folders on the same provider versions. Do not copy `.terraform/` or apply `remote/` before migrating.

## 4. Verify

```bash
terraform output
terraform plan
aws s3 ls "s3://$STATE_BUCKET/terraform-state/"
```

Expect the same bucket name and ARN, a **no-change plan**, and `terraform.tfstate` listed in S3. Only state storage moved.

Use only `remote/` from now on. Keep state out of Git; provider lockfiles belong in Git.

## Next: EC2

Continue with [EC2 basics](../01-ec2-basics/README.md). Each lab has its own fixed state key in the shared bucket: one deployment of each lab per bucket.

Keep the bucket for the later labs. Its deletion is protected because it also stores its own state. See the [instructor guide](instructor-guide.md) for teaching notes and backend retirement.
