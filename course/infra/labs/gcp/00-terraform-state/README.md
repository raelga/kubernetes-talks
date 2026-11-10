# Terraform: bootstrap a Cloud Storage state backend

This lab creates a private Cloud Storage bucket with Terraform, then migrates its state into the bucket. The bucket also holds state for [Compute basics](../01-compute-basics/README.md).

## Before you start

- Install Terraform >= 1.10 and < 2.0 and the Google Cloud CLI. Use an approved project with billing enabled.
- Terraform generates a unique bucket name with a persistent random suffix. The default location is Oregon (`US-WEST1`); override `location` if needed.
- Check that your identity can create and delete buckets and their objects. Do not change IAM or organization policy merely to make the demo work.
- Complete [project setup and Terraform sign-in](../README.md#sign-in-for-terraform). The CLI and Terraform use separate credentials; select the intended account for ADC.
- Keep state and backups private: they can contain secrets. Uniform bucket access and public access prevention do not replace private IAM permissions.

## 1. Create with local state

Complete the [Google Cloud bootstrap](../README.md#sign-in-for-terraform) in this terminal, then check your project and initialize:

```sh
cd course/infra/labs/gcp/00-terraform-state
gcloud config get-value project
terraform init
terraform plan
```


Review the plan: it should create one bucket in the intended project and location. Only then run `terraform apply` and confirm. The bucket has uniform access, enforced public access prevention and object versioning from creation; `force_destroy = false` prevents Terraform from emptying a nonempty bucket automatically.

```sh
terraform apply
terraform state list
terraform state show google_storage_bucket.state
terraform output
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
```

Initially the state is local in `terraform.tfstate`. Protect the working directory and any backups. The `.gitignore` excludes local state, backend configuration and variable files; review generated files before committing. Provider lockfiles should be committed for reproducible installations, but never commit credentials or state.

## 2. Migrate state to the bucket

Copy the supplied backend template into place, then initialize the GCS backend using the bucket just created. Backend configuration cannot reference Terraform variables or outputs directly. Confirm the migration prompt; do not run `apply` before successful migration.

```sh
cp backend.tf.example backend.tf
terraform init -migrate-state -backend-config="bucket=$STATE_BUCKET"
terraform state list
terraform output
terraform plan
```

Migration moves the state, not the bucket. The plan should show no changes and the output should name the same bucket. Stop if Terraform proposes creating or replacing it: check the project, inputs and state rather than applying. Terraform may retain a local state backup; secure it and do not use it as an independent source of truth. After migration, use this initialized directory and remote state only. GCS state locking helps prevent simultaneous writers; never force-unlock an active operation.

Inspect object names without printing state contents:

```sh
gcloud storage ls --all-versions "gs://$STATE_BUCKET/gcp/terraform-state/**"
```

The default workspace state is under `gcp/terraform-state/`; other labs use their own prefixes. Backend access requires appropriate object permissions independently of permissions to manage the bucket. If migration is interrupted, stop and inspect both state locations and locks before retrying; do not overwrite either copy blindly.

## 3. Costs

Cloud Storage charges for stored data, operations and some network traffic. Check [Cloud Billing reports](https://cloud.google.com/billing/docs/how-to/reports) and [budgets](https://cloud.google.com/billing/docs/how-to/budgets). Reports may be delayed, and budgets do not automatically stop spending. Versioned and soft-deleted objects may still incur charges.

Keep this bucket: the GCP labs share it for Terraform state. Do not destroy it during lab cleanup.
