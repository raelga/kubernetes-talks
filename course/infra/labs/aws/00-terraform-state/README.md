# Terraform: Create an S3 State Backend

Create a bucket locally, migrate its state to S3, then enable versioning and deletion protection from `remote/`. Later labs reuse the bucket.

Use Terraform `>=1.10,<2`, AWS CLI v2 and configured AWS credentials. The default region is `us-east-1`, which works with the tested UPC Academy role. Run commands in order in the **same terminal**.

This lab uses `awscc_s3_bucket` (AWS Cloud Control): the tested Academy role denies an Object Lock metadata read required by the standard S3 resource.

## 1. Create locally

From the repository root, `cd` changes your working directory:

```sh
cd course/infra/labs/aws/00-terraform-state/local
```

`init` installs providers and prepares local state storage.

```sh
terraform init
```

`plan` previews changes without deploying them.

```sh
terraform plan
```

`apply` asks for confirmation; enter `yes` to create the bucket.

```sh
terraform apply
```

`state list` lists the resources Terraform manages.

```sh
terraform state list
```

`state show` displays one resource's recorded attributes.

```sh
terraform state show awscc_s3_bucket.state
```

Illustrative excerpt; your random suffix will differ:

```text
❯ terraform state show awscc_s3_bucket.state
# awscc_s3_bucket.state:
resource "awscc_s3_bucket" "state" {
    arn         = "arn:aws:s3:::upc-k8s-terraform-state-a1b2"
    bucket_name = "upc-k8s-terraform-state-a1b2"
    id          = "upc-k8s-terraform-state-a1b2"
}
```

`bucket_name` names the bucket; `arn` identifies it in AWS. The four-character suffix reduces naming collisions. It is not your AWS account ID.

`output` shows values exposed by the configuration.

```sh
terraform output
```

Save the bucket name in an environment variable. `-raw` returns the plain value.

```sh
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

The bucket is private and encrypted. Locally, versioning is off and `prevent_destroy = false`; state lives in `local/terraform.tfstate`.

## 2. Migrate to S3

Copy state into the remote folder. The original remains as a backup.

```sh
cp terraform.tfstate ../remote/terraform.tfstate
```

Copy the provider lockfile to preserve provider versions and checksums.

```sh
cp .terraform.lock.hcl ../remote/.terraform.lock.hcl
```

Switch to the fixed remote configuration.

```sh
cd ../remote
```

Migrate the copied state into the bucket. Confirm the prompt with `yes`.

```sh
terraform init -migrate-state -backend-config="bucket=$STATE_BUCKET"
```

Do not copy `.terraform/` or apply the remote configuration before migration. No waiting period is needed here: versioning has not been enabled yet.

## 3. Enable remote protection

Preview the remote settings. Expect **one in-place update** enabling versioning, not a new bucket. This configuration also sets `prevent_destroy = true`.

```sh
terraform plan
```

Apply those settings to the existing bucket.

```sh
terraform apply
```

AWS recommends allowing propagation after first enabling versioning before subsequent object writes. This sequence avoids a timed wait before migration; propagation is still asynchronous.

## 4. Verify

Outputs should show the same bucket name and ARN as before migration.

```sh
terraform output
```

Expect **no changes** now.

```sh
terraform plan
```

List the remote state object in S3.

```sh
aws s3 ls "s3://$STATE_BUCKET/terraform-state/"
```

Use only `remote/` afterward; the original local state is stale. Keep state out of Git; commit provider lockfiles.

## Next labs

Continue with [EC2 basics](../01-ec2-basics/README.md) or [WordPress](../02-wordpress/README.md). Each lab uses a fixed state key: one deployment per lab per bucket.

Keep this bucket while it stores state. For another approved region, see [region overrides](../../../README.md). If preserving a bucket with an older name, set `TF_VAR_bucket_name` to its actual name before planning; do not force replacement.
