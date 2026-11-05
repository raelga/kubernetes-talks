# EC2 basics: Security Groups and User Data

Deploy one public EC2 instance. A security group allows HTTP, and user-data installs Apache and checks out the application automatically. No ALB, NAT Gateway, database or TLS setup.

Prerequisites: Terraform `>=1.10,<2`, AWS CLI v2, configured AWS credentials, and the completed [state bucket lab](../00-terraform-state/README.md). The `aws_region` variable defaults to `us-east-1`; see [region overrides](../../../README.md) if needed.

## 1. Deploy

From the repository root:

```sh
cd course/infra/labs/aws/01-ec2-basics/infra
export STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform plan
terraform apply
terraform output -raw application_url
```

Review and approve the apply. Open the output URL once installation finishes; the page shows the instance hostname and Git commit. The backend uses `ec2-basics/terraform.tfstate`: one deployment per bucket.

## 2. Understand the security group

Find the instance's security group in the AWS console:

- **Inbound:** port 80 from the internet lets you open the page. SSH stays closed.
- **Outbound:** lets EC2 download packages and check out the public repository.
- Replies to allowed connections are permitted automatically: security groups are stateful.

The public subnet routes through an Internet Gateway. The browser connects directly to EC2's public IP.

## 3. Understand user-data

Read `user_data` in [`infra/main.tf`](infra/main.tf). It runs [`infra/install.sh`](infra/install.sh) at launch to install Apache and Git, create `/opt/infra-lab`, and check out the application. No manual installation commands are needed.

Inspect the instance's system log in the EC2 console to see installation output. Changing user-data replaces this lab's instance; simply rebooting does not rerun the installation.

## 4. Cleanup

```sh
terraform destroy
```

Review, confirm, and wait for completion. The shared state bucket remains. EC2, public IPv4 and disk storage incur charges. HTTP is public and unencrypted; use demo data only.
