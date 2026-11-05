# Private EC2 behind an ALB

Deploy a public load balancer and private EC2 running Apache. User-data runs [`infra/install.sh`](infra/install.sh) automatically; no manual installation is needed.

Use Terraform `>=1.10,<2`, AWS CLI v2 and your configured AWS account/region. Complete the [state bucket lab](../00-terraform-state/README.md) first.

## 1. Deploy

From the repository root:

```sh
cd course/infra/labs/aws/01-ec2-basics/infra
aws sts get-caller-identity
STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform plan
terraform apply
```

Review and approve the apply. Terraform uses a fixed `ec2-basics/terraform.tfstate` key in your bucket. Run one deployment of this lab per bucket.

The installer checks out this repository's published `main` branch and serves [`app/`](app/). A NAT Gateway gives private EC2 outbound access. Changes to the installer, Git ref or selected AMI can replace EC2; review the plan.

## 2. Open the application

```sh
terraform output -raw application_url
```

Open that URL in your browser. Wait for installation and ALB health checks to finish; early requests may return 503. The page shows the instance hostname and Git commit.

## 3. Understand the security groups

Inspect them in the AWS console:

- The public ALB accepts HTTP from any IPv4 client.
- Private EC2 accepts port 80 only from the ALB security group.
- EC2 has no public IP or SSH access.

Optional HTTPS: set both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a new hostname in your existing public Route 53 zone, then plan/apply again. This adds ACM, DNS validation and the HTTPS listener.

## 4. Cleanup

```sh
terraform destroy
```

Review, confirm, and wait for completion. The shared state bucket and existing DNS zone remain. ALB and NAT incur charges until destroyed; stopping EC2 is not cleanup.

For troubleshooting, use the SSM command from `terraform output -raw ssm_start_session_command` (Session Manager plugin required), then inspect `/var/log/cloud-init-output.log`. Keep EC2 private.
