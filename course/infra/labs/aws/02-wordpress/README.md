# WordPress on private EC2 and RDS

Deploy a public ALB, private EC2 and private RDS MySQL with one command. EC2 randomly selects one private subnet; its selection persists in Terraform state.

Use Terraform `>=1.11,<2`, AWS CLI v2, Python 3, `jq`, and the AWS Session Manager plugin. Configure AWS Academy credentials for `us-east-1`, complete the [shared state bucket lab](../00-terraform-state/README.md), and provide its bucket name through that lab's Terraform output or `STATE_BUCKET`.

Academy must provide `LabInstanceProfile`/`LabRole`. EC2 needs SSM access and permission to read the application secret. The deploying identity needs permission to manage AWS resources, read/update the application secret, read the RDS administrator secret, invoke SSM Run Command for bootstrap recovery, and start an `AWS-StartPortForwardingSessionToRemoteHost` session to EC2. No SSH or public MySQL access is opened; no IAM role or policy is created.

## Deploy

From the repository root, enter this lab.

```sh
cd course/infra/labs/aws/02-wordpress
```

Deploy both stacks and configure the database user through a temporary SSM tunnel.

```sh
./deploy.sh
```

The script initializes two encrypted, locked S3 states (`wordpress/terraform.tfstate` and `wordpress-database/terraform.tfstate`), deploys infrastructure, initializes the app secret outside Terraform state, starts a loopback-only SOCKS5 bridge over SSM, and uses the MySQL provider to create `wordpress_app` and its database-scoped grants. Keep `TF_LOG` unset: MySQL-provider debug logs can expose administrator connection details.

## Credentials and state
- `deploy.sh` generates the dedicated WordPress database password and WordPress authentication keys/salts locally. The salts sign authentication cookies; they are not database-password salts. It writes the JSON secret directly to Secrets Manager through a mode-0600 temporary file. The value is not passed on a command line or stored in Terraform state.
- After the private tunnel is ready, `with-ssm-tunnel.sh` passes the password as an ephemeral Terraform input to the MySQL provider's write-only `password_wo` argument. Neither database state nor saved plans retain the password; state tracks only the non-secret `password_version`. Increment that field when manually rotating the application password, then rerun `./deploy.sh`. Keep both encrypted S3 states private and never enable `TF_LOG`.
- A root cron job fetches **only** the application secret once per minute and atomically refreshes `/etc/infra-lab/database.json`. Apache reads it on each PHP request. Failed fetches leave the previous valid credentials intact. On the first deployment, the native WordPress database error can appear briefly until cron completes.
- Database-user credentials are separate from the WordPress admin credentials you set in the browser. The ALB health check uses `/wp-login.php`.

Inspect the private database and security groups in Terraform state or the AWS console.

```sh
terraform -chdir=infra state show aws_db_instance.app
```

## Rerun and cleanup

After fixing connectivity, rerun `./deploy.sh`. SSM checks cloud-init and reruns the saved, idempotent installer only when first boot failed; uploads on the same instance are preserved. The app secret is reused and the SQL user is managed idempotently. Download retries are bounded and checksum failures stop installation. If SSM recovery is unavailable, inspect the EC2 console output and restore the required SSM permissions.

Destroy the SQL user first through the same SSM tunnel, then destroy RDS and the rest of the stack.

```sh
./destroy.sh
```

Review and confirm both deletion plans. Database contents and uploads are deleted, with no final database snapshot. Destroying the infrastructure removes its application-secret metadata and versions. The shared state bucket, Academy IAM resources and any existing Route 53 zone remain. ALB, NAT Gateway, EC2 and RDS incur charges until destroyed.

Existing deployments preserve database, subnet group and security-group identities with Terraform `moved` blocks. Applying the new installer replaces EC2 once; files and uploads on the old instance disk are lost. Review both plans and back up any uploads before upgrading.
