# WordPress with a local Terraform module (AWS)

This lab uses the reusable module at `course/infra/modules/aws/wordpress-stack`. The root configures the AWS provider and S3 backend, passes inputs to the module, and exposes its outputs. The module creates a public ALB, private EC2 instance and private RDS MySQL database, networking and application secrets. EC2 selects a private subnet and the selection persists in state. Use demo data only.

## Prerequisites

Use Terraform `>=1.10,<2`, AWS CLI v2 and AWS Academy credentials. Complete the [state bucket lab](../00-terraform-state/README.md) and retain its bucket name. The default region is `us-east-1`; for another approved region set `TF_VAR_aws_region` and use the same region when initializing the backend.

Academy must supply `LabInstanceProfile`/`LabRole`, or specify an existing profile using `TF_VAR_instance_profile_name`. The instance role needs permission to read both the application secret and RDS-managed administrator secret with `secretsmanager:GetSecretValue` (and `kms:Decrypt` for a customer-managed key), plus SSM permissions for troubleshooting. The deploying identity needs permission to manage the stack, pass the role, and create and write the application secret; RDS must be allowed to manage its administrator secret. Academy permissions vary: resolve explicit denies with the instructor. This lab does not create or modify IAM roles or policies. No SSH or public MySQL access is needed.

## State isolation and deployment

This is a separate deployment, not an upgrade or migration of [02-wordpress](../02-wordpress/README.md). Its backend key is `wordpress-module/terraform.tfstate`, distinct from `wordpress/terraform.tfstate`, and its resource names use a distinct prefix. Both labs can share the state bucket without sharing state. Never point this lab at the other lab's key, import its resources, or destroy its state. If using optional DNS, choose a **different new hostname** from any other deployment; Route 53 records are not isolated by Terraform state.

For separate deployments of this lab, assign each a distinct `lab_id` and a distinct S3 backend key. After changing to the lab directory and setting `STATE_BUCKET` as below, for example, set `export TF_VAR_lab_id=team-a` and `export TF_DATA_DIR="$PWD/.terraform-team-a"`, then initialize with `terraform init -backend-config="bucket=$STATE_BUCKET" -backend-config="key=wordpress-module/team-a/terraform.tfstate"`. Use a different label, data directory and key for each deployment, and consistently select them for init, plan, apply and destroy. The generated resource suffix further distinguishes module instances; optional DNS hostnames must still be unique. Never switch an existing deployment's key as a substitute for state migration.

From the repository root:

```sh
cd course/infra/labs/aws/03-wordpress-module
# If not already exported by the state lab:
export STATE_BUCKET="$(terraform -chdir=../00-terraform-state/remote output -raw state_bucket_name)"
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform plan
terraform apply
terraform output application_url
```

For a non-default region add `-backend-config="region=$TF_VAR_aws_region"` to `init`. Review the plan before applying. Open the application URL and complete WordPress setup; the WordPress administrator login is separate from the database user. Bootstrap continues asynchronously after EC2 creation, so wait for the ALB target to become healthy. Its health check uses `/wp-login.php`.

Inputs are declared in `variables.tf` and forwarded to the module in `main.tf`: region, instance profile, lab label, EC2 and database sizes, MySQL version, WordPress version and SHA-256, and optional `domain_name` and `hosted_zone_id`. Set both DNS inputs for HTTPS using a new hostname in an existing public Route 53 zone; otherwise use the HTTP ALB URL. Override the WordPress version and its matching official archive digest together. Outputs from the module are available through `terraform output`; for example, inspect the database without displaying secret resources:

```sh
terraform state show 'module.wordpress_stack.aws_db_instance.app'
```

The installer needs outbound access to the Python package index, AWS services and WordPress download site. It installs boto3 and PyMySQL in a virtual environment, retries database provisioning on boot, and uses cron to retry each minute if needed. It retrieves the RDS administrator secret and application secret to provision the database-scoped `wordpress_app` user; neither password is embedded in EC2 user-data. If bootstrap fails, inspect cloud-init via SSM without exposing secrets. After correcting permissions or connectivity, rerun `/opt/infra-lab/install.sh` on the instance; it preserves existing uploads. A root cron job refreshes application credentials in `/etc/infra-lab/database.json` for Apache.

## Credentials and cleanup

**The generated application password and WordPress authentication keys and salts are sensitive and stored in Terraform state; saved plans may contain them too.** Sensitive markings only hide normal CLI display. Restrict access to the encrypted S3 bucket, its version history, saved plans and backups; never commit, print or share them, or enable Terraform debug logging. RDS manages its own administrator secret. Do not rotate the application secret independently in Secrets Manager: Terraform owns its version and the SQL user must be updated consistently; changing salts invalidates WordPress login cookies.

When finished, from this lab directory:

```sh
terraform plan -destroy
terraform destroy
```

Review and confirm the destruction plan. This deletes this module's RDS database and automated backups without a final snapshot, EC2 uploads, and the application secret and versions. ALB, NAT Gateway, EC2 and RDS incur charges until destroyed. The shared state bucket, Academy IAM resources, existing Route 53 zone and the separate 02 lab remain. Retained S3 state versions and saved plans can still contain credentials; handle them according to your retention policy.
