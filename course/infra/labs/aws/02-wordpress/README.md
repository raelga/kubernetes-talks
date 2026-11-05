# Private EC2 + WordPress + MySQL

Deploy the web tier, then add private MySQL without replacing EC2.

Prerequisites: Terraform `>=1.10,<2`, AWS CLI v2, a configured AWS account and region, this repository checked out, and the completed [state bucket lab](../00-terraform-state/README.md). Account, region, resource names and the official Amazon Linux 2023 AMI are automatic; no AMI export is needed.

## 1. Deploy the web tier

From the repository root:

```sh
cd course/infra/labs/aws/02-wordpress/infra
export STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform plan
terraform apply
terraform output -raw application_url
```

User-data runs [`infra/install.sh`](infra/install.sh) automatically. It installs Apache/PHP and downloads WordPress into `app/public/` (the web root).

The database is disabled by default. Once installation and health checks finish, the page reports that WordPress files are ready but the database is not configured.

The fixed backend key is `wordpress/terraform.tfstate`: use **one deployment of this lab per bucket**. Terraform keeps the existing instance's AMI when newer images appear.

## 2. Follow the security groups

Inspect the chain in the AWS console:

- Internet → public ALB on HTTP.
- ALB security group → private EC2 on port 80.
- EC2 security group → private RDS on port 3306, added next.

EC2 and RDS have no public access. A NAT Gateway provides EC2 outbound connectivity.

## 3. Add MySQL and finish WordPress

```sh
export TF_VAR_enable_database=true
terraform plan
terraform apply
terraform output -raw application_url
```

Review the plan: it should add the database and configuration, **not replace EC2**. Terraform runs the configuration helper automatically through an SSM association and waits for success. The instance retrieves its database credentials from Secrets Manager; the password is not passed through Terraform state or SSM command arguments.

Open the URL and complete the **browser-based WordPress installer** to create the site. HTTP is public and unencrypted: use unique demo credentials and no sensitive data.

Keep `TF_VAR_enable_database=true` set through cleanup, including when resuming in another terminal. Setting it to `false` and applying deletes the database; it is not a pause switch.

## 4. Cleanup

```sh
terraform destroy
```

Review, confirm, and wait for completion. **Database contents and uploads are deleted**, with no final database snapshot. The shared state bucket remains. ALB, NAT, EC2 and RDS incur charges until destroyed.

If configuration fails, inspect the SSM association execution and `/var/log/cloud-init-output.log`; never print credentials or make EC2/RDS public. Optional HTTPS: set both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a new hostname in an existing public Route 53 zone, then plan/apply. Terraform creates the certificate and DNS records; the existing zone remains after cleanup.
