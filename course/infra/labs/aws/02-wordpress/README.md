# WordPress on private EC2 and RDS

Deploy a public ALB, private EC2 and private RDS MySQL with one Terraform stack. EC2 randomly selects one private subnet; its selection persists in Terraform state. Use demo data only.

## Prerequisites

Use Terraform `>=1.10,<2`, AWS CLI v2 and AWS Academy credentials. Complete the [shared state bucket lab](../00-terraform-state/README.md), retaining its `STATE_BUCKET` variable or the bucket name from its Terraform output. The default region is `us-east-1`; for another approved region set `TF_VAR_aws_region` and supply the same region to backend initialization.

Academy must provide `LabInstanceProfile`/`LabRole`. Before deploying, check that the instance role is allowed to read **both** the application secret and the RDS-managed administrator secret with `secretsmanager:GetSecretValue` (and `kms:Decrypt` if a customer-managed key is used). It also needs SSM permissions for troubleshooting. The deploying identity needs permissions to create and manage the stack, pass the instance role, and create and write the application secret; RDS must be allowed to manage its administrator secret. Academy permissions vary: resolve any explicit denies with the instructor; this lab does not create or modify IAM roles or policies. No SSH or public MySQL access is needed.

## Deploy

From the repository root:

```sh
cd course/infra/labs/aws/02-wordpress
# If not already exported by the state lab:
export STATE_BUCKET="$(terraform -chdir=../00-terraform-state/remote output -raw state_bucket_name)"
terraform -chdir=infra init -backend-config="bucket=$STATE_BUCKET"
terraform -chdir=infra plan
terraform -chdir=infra apply
terraform -chdir=infra output application_url
```

For a non-default region add `-backend-config="region=$TF_VAR_aws_region"` to `init`. Review the plan before applying. Open the application URL and complete the WordPress setup in the browser; the WordPress administrator login is separate from the database user. Bootstrap runs asynchronously after Terraform creates EC2, so wait for the ALB target to become healthy. The ALB health check uses `/wp-login.php`.

The installer installs a Python virtual environment with boto3 and PyMySQL, then retries database provisioning during initial boot; cron continues retrying each minute if needed. It reads the administrator secret when credentials are missing or have changed, and publishes application credentials only after provisioning and a successful database connection. If bootstrap fails, check EC2 cloud-init and SSM access without exposing secrets; after correcting permissions or connectivity, the saved `/opt/infra-lab/install.sh` can be rerun on the instance and preserves existing uploads. The instance needs outbound access to the Python package index as well as the AWS services and WordPress download site.

Terraform creates an application secret version with a generated database password and WordPress authentication keys/salts. EC2 retrieves the RDS-managed administrator secret and application secret to create or update the database-scoped `wordpress_app` SQL user, then uses the application credentials for WordPress. The administrator password and application password are not embedded in EC2 user-data. RDS accepts MySQL connections only from the application security group. A root cron job refreshes the application credentials in `/etc/infra-lab/database.json`; Apache reads that file for requests. Authentication salts sign cookies, not database passwords.

## Credentials and state

**The generated application password and salts are sensitive and are stored in Terraform state and may appear in saved plans.** `sensitive` markings hide normal CLI display; they do not encrypt the values in state. The S3 backend enables encryption and locking, but bucket access must still be restricted. Protect state, its version history and any saved plans or backups; never commit or print them, enable Terraform debug logging, or share them as lab captures. The RDS administrator secret is managed by RDS, not generated as a Terraform input.

Inspect the private database and security groups without printing secret resources:

```sh
terraform -chdir=infra state show aws_db_instance.app
```

Do not rotate the application secret independently in Secrets Manager: Terraform owns its version and the database user must be updated consistently. A fresh secret and SQL-user password can interrupt service and new salts invalidate existing WordPress login cookies.

## Existing two-stack deployments

Before upgrading, back up database contents and EC2 uploads outside Git and plan a maintenance window. The existing `wordpress/terraform.tfstate` remains the infrastructure state; use the same bucket, region and variables. The `moved` blocks preserve existing database, subnet-group and security-group addresses. Review the plan and stop if it proposes unexpected RDS replacement or deletion. The installer change replaces EC2, so uploads on the old instance disk are lost unless backed up and restored.

The first apply creates a new Terraform-managed application secret version and password, replacing the previous current version; bootstrap updates the existing SQL user. Expect downtime until the new instance has completed bootstrap, and expect WordPress sessions to be invalidated. Preserve the old secret version and a protected backup of the old states for recovery. The old `wordpress-database/terraform.tfstate` is now obsolete: **do not apply or destroy that old stack**, because it manages the same SQL user and could revoke its grants or delete it. Retire its protected state and version history according to your data-retention policy only after confirming the new deployment and backups. Do not delete the shared state bucket.

## Cleanup

```sh
terraform -chdir=infra plan -destroy
terraform -chdir=infra destroy
```

Review and confirm the deletion plan. Destroying RDS also removes its SQL user, database contents and automated backups; no final database snapshot is taken. EC2 uploads and the application secret and its versions are deleted. The shared state bucket, Academy IAM resources and any existing Route 53 zone remain. ALB, NAT Gateway, EC2 and RDS incur charges until destroyed. Retained S3 state versions and saved plans can still contain credentials and must be handled under your retention policy.
