# Private EC2 behind an ALB

Deploy a public load balancer and private EC2 running Apache. [`infra/install.sh`](infra/install.sh) installs the application automatically.

Prerequisites: Terraform `>=1.10,<2`, AWS CLI v2, a configured AWS account and region, this repository checked out, and the completed [state bucket lab](../00-terraform-state/README.md). Account, region and resource names are automatic.

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

Review and approve the apply. The fixed backend key is `ec2-basics/terraform.tfstate`: use **one deployment of this lab per bucket**.

Open the output URL. Installation and health checks take time; an early request may return 503. The page shows the instance hostname and Git commit. The installer uses this repository's published `main` branch.

## 2. Follow the security groups

Inspect the chain in the AWS console:

- Internet → public ALB on HTTP.
- ALB security group → private EC2 on port 80.
- EC2 has no public IP or SSH access; a NAT Gateway provides outbound connectivity.

HTTP is public and unencrypted: use demo data only.

## 3. Cleanup

```sh
terraform destroy
```

Review, confirm, and wait for completion. The shared state bucket remains. ALB, NAT and EC2 incur charges until destroyed; stopping EC2 is not cleanup.

See the [instructor guide](instructor-guide.md) for troubleshooting and optional HTTPS.
