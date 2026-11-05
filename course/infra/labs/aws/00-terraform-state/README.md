# Terraform: Create an S3 State Backend

Create a bucket with local state, then move that state into S3. Later labs reuse the bucket.

## 1. Get ready

Install Terraform `>=1.10,<2` and AWS CLI v2, configure your AWS account and region, and check out this repository. Use the same AWS environment throughout; account, region and default bucket naming are automatic. No `.tf` edits are needed.

From the repository root:

```sh
cd course/infra/labs/aws/00-terraform-state/local
terraform init
terraform plan
terraform apply
terraform state list
terraform state show aws_s3_bucket.state
terraform output
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

Review and approve the apply. The bucket is private, encrypted and versioned. Terraform state records the resources it manages; it currently lives in `local/terraform.tfstate`.

## 2. Move state to S3

**Wait 15 minutes after first enabling bucket versioning.** With no other Terraform operation running:

```sh
cp terraform.tfstate ../remote/terraform.tfstate
cp .terraform.lock.hcl ../remote/.terraform.lock.hcl
cd ../remote
terraform init -migrate-state -backend-config="bucket=$STATE_BUCKET"
```

Approve migration. The original local state remains as a backup; the lockfile preserves provider versions. Do not copy `.terraform/` or apply `remote/` before migrating.

## 3. Verify

```sh
terraform output
terraform plan
aws s3 ls "s3://$STATE_BUCKET/terraform-state/"
```

Expect unchanged outputs, a **no-change plan**, and `terraform.tfstate` in S3. Only state storage moved. Use `remote/` from now on; the local backup is stale. Keep state out of Git.

## Next labs

Continue with [EC2 basics](../01-ec2-basics/README.md) or [WordPress](../02-wordpress/README.md). Fixed state keys allow **one deployment of each lab per bucket**. S3 encryption and native state locking remain enabled.

Keep this protected bucket for the later labs; do not destroy it while it holds their state. See the [instructor guide](instructor-guide.md) for retirement notes.
