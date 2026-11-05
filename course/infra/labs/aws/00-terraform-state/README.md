# Terraform: Create an S3 State Backend

Create a bucket with local state, then move that state into S3. Later labs reuse the bucket.

## 1. Create the bucket locally

You need Terraform `>=1.10,<2`, AWS CLI v2, configured AWS credentials, and this repository checked out. Terraform's `aws_region` variable defaults to `eu-west-1`; no region setup is required. Run the commands in order in the **same terminal**. No `.tf` edits are needed. See [region overrides](../../../README.md) if using another region.

From the repository root, `cd` changes your working directory to the local configuration:

```sh
cd course/infra/labs/aws/00-terraform-state/local
```

`init` downloads the required providers and prepares the working directory. This folder uses local state.

```sh
terraform init
```

`plan` previews the resources Terraform will create. It does not deploy them.

```sh
terraform plan
```

`apply` shows the plan and asks for confirmation. Enter `yes` to create the bucket and its settings.

```sh
terraform apply
```

`state list` lists the resource addresses recorded in Terraform state—not every resource in your AWS account.

```sh
terraform state list
```

`state show` displays the recorded attributes of one resource, including the bucket name and ARN.

```sh
terraform state show aws_s3_bucket.state
```

`output` displays the values exposed by this configuration, such as the bucket name and region.

```sh
terraform output
```

`export` saves the bucket name as a shell environment variable. `output -raw` returns just its value, without quotes.

```sh
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

The bucket is private, encrypted and versioned. State currently lives in `local/terraform.tfstate`.

## 2. Move state to S3

**Wait 15 minutes after first enabling bucket versioning.** Stop other Terraform operations before migrating.

`cp` copies the existing state into the remote configuration. The original remains in `local/` as a backup.

```sh
cp terraform.tfstate ../remote/terraform.tfstate
```

Copy the provider lockfile so both folders use the same provider versions and checksums.

```sh
cp .terraform.lock.hcl ../remote/.terraform.lock.hcl
```

Change to the remote configuration, which already declares the S3 backend.

```sh
cd ../remote
```

`init -migrate-state` moves the copied local state into S3. `-backend-config` supplies the bucket name. Approve the migration prompt.

```sh
terraform init -migrate-state -backend-config="bucket=$STATE_BUCKET"
```

Do not copy `.terraform/` or apply `remote/` before migrating. Only state storage is changing—not the bucket.

## 3. Verify the migration

Display the outputs again. The bucket name and ARN should match the local deployment.

```sh
terraform output
```

Check that Terraform recognizes the existing resources. Expect **no changes**.

```sh
terraform plan
```

List the state prefix in S3. You should see `terraform.tfstate`.

```sh
aws s3 ls "s3://$STATE_BUCKET/terraform-state/"
```

Use only `remote/` from now on; the original local state is a stale backup. Keep state out of Git.

## Next labs

Continue with [EC2 basics](../01-ec2-basics/README.md) or [WordPress](../02-wordpress/README.md). Fixed state keys allow **one deployment of each lab per bucket**. S3 encryption and native state locking remain enabled.

Keep this protected bucket for the later labs; do not destroy it while it holds their state. See the [instructor guide](instructor-guide.md) for retirement notes.
