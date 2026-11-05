# Private EC2 + WordPress + MySQL

Deploy a public ALB and private WordPress EC2 first, then add private MySQL without replacing EC2.

EC2 randomly selects one of the two private subnets. The choice persists across applies; destroying and recreating the stack makes a new selection.

Use Terraform `>=1.10,<2`, AWS CLI v2, configured AWS Academy credentials in `us-east-1`, and the completed [state bucket lab](../00-terraform-state/README.md).

The lab reuses Academy's `LabInstanceProfile`/`LabRole`; it creates no IAM roles or policies. EC2 needs SSM and Secrets Manager access.

## 1. Deploy the web tier

From the repository root, enter the Terraform directory.

```sh
cd course/infra/labs/aws/02-wordpress/infra
```

Read the shared bucket name from the state lab.

```sh
export STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
```

Initialize the backend with its fixed key, `wordpress/terraform.tfstate`. Use one deployment of this lab per state bucket.

```sh
terraform init -backend-config="bucket=$STATE_BUCKET"
```

Preview the web tier. The database is disabled by default.

```sh
terraform plan
```

Create the web tier; review the plan and confirm with `yes`.

```sh
terraform apply
```

Print the URL and open it in your browser. Allow time for automatic installation and ALB health checks.

```sh
terraform output -raw application_url
```

User-data runs [`infra/install.sh`](infra/install.sh), installs Apache/PHP and downloads WordPress into `app/public/`. The first page explains that the files are ready but the database is not configured.

## 2. Inspect the security group chain

Inspect the ALB security group and its rules in the AWS console, using this resource to identify it.

```sh
terraform state show aws_security_group.alb
```

The public ALB accepts HTTP on port 80; HTTPS on port 443 is optional when a domain and certificate are configured.

Inspect the private EC2 security group. HTTP on port 80 is allowed only from the ALB security group, with no SSH ingress.

```sh
terraform state show aws_security_group.app
```

EC2 has no public IP; a NAT Gateway provides outbound connectivity.

## 3. Add MySQL

Enable the database for subsequent Terraform commands.

```sh
export TF_VAR_enable_database=true
```

Review the plan: it should add the database and configuration, **not replace EC2**.

```sh
terraform plan
```

Apply and confirm with `yes`. Terraform configures WordPress automatically through an SSM association and waits for success.

```sh
terraform apply
```

Inspect the database security group and its rules in the AWS console. Private RDS accepts MySQL on port 3306 only from the EC2 security group.

```sh
terraform state show 'aws_security_group.database[0]'
```

RDS manages the database password in Secrets Manager. EC2 retrieves it at runtime; the password is not persisted in Terraform state or passed as an SSM command argument. Do not print or commit credentials.

Print the application URL again.

```sh
terraform output -raw application_url
```

Open it and complete the **browser-based WordPress installer** to create the site. Public HTTP is unencrypted: use unique demo credentials and no sensitive data.

`/readiness.php` returns HTTP 503 before database configuration, then HTTP 200 with `installer-ready` when the database connects. It reports `installed` once the installer saves the WordPress site URL.

Keep `TF_VAR_enable_database=true` set through cleanup, including when resuming in another terminal. Setting it to `false` and applying deletes the database; it is not a pause switch.

## 4. Cleanup

Delete this stack's resources. Review, confirm with `yes`, and wait for completion.

```sh
terraform destroy
```

**Database contents and uploads are deleted**, with no final database snapshot. The shared state bucket and existing Academy IAM resources remain. ALB, NAT Gateway, EC2 and RDS incur charges until destroyed.

For configuration failures, inspect the SSM association execution and EC2 console system log without exposing credentials or making private resources public. Optional HTTPS requires both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a new hostname in an existing public Route 53 zone; then repeat the plan and apply steps. Terraform creates the certificate and DNS records; the existing zone remains after cleanup.
