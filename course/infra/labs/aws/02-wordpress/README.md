# Private EC2 + WordPress + MySQL

Deploy the web tier first, then add a private MySQL database without replacing EC2.

Use Terraform `>=1.10,<2`, AWS CLI v2, curl and jq with your configured AWS account/region. Complete the [state bucket lab](../00-terraform-state/README.md) first. Keep the same terminal and AMI throughout this lab.

## 1. Deploy the web tier

From the repository root:

```sh
cd course/infra/labs/aws/02-wordpress/infra
aws sts get-caller-identity
STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
export TF_VAR_ami_id="$(aws ec2 describe-images --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-kernel-6.1-x86_64' \
    'Name=architecture,Values=x86_64' 'Name=virtualization-type,Values=hvm' \
    'Name=state,Values=available' \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)"
terraform init -backend-config="bucket=$STATE_BUCKET"
terraform plan
terraform apply
APP_URL="$(terraform output -raw application_url)"
printf '%s\n' "$APP_URL"
```

Review and approve the apply. The database is disabled by default. Open the URL after installation and health checks finish: WordPress files are ready, but the database is not configured.

The backend uses the fixed `wordpress/terraform.tfstate` key. Run one deployment of this lab per bucket. Do not repeat the AMI lookup between stages; if resuming, recover the original ID with `terraform output -raw ami_id`.

## 2. Understand the security groups

Inspect them in the AWS console:

- Internet → public ALB on HTTP, or HTTPS when configured.
- ALB security group → private EC2 on port 80.
- EC2 security group → private RDS on port 3306, added next.

EC2 and RDS have no public access. A NAT Gateway provides EC2 outbound connectivity.

## 3. Add MySQL

```sh
export TF_VAR_enable_database=true
terraform plan
terraform apply
```

Review the plan: it should add the database and its access rules, **not replace EC2**. Keep the AMI and other web settings unchanged. All `.tf` files form one stack; no `-target` is needed.

## 4. Connect WordPress

Get the instance ID and wait until SSM reports `Online`:

```sh
INSTANCE_ID="$(terraform output -raw instance_id)"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].PingStatus'
```

Run the configuration helper on EC2. It fetches credentials inside the instance; passwords do not enter these commands or Terraform state.

```sh
PARAMETERS="$(terraform output -json | jq -c '{commands: [
  (["php", "/opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app/configure.php",
    "--endpoint", .database_endpoint.value,
    "--secret-arn", .database_secret_arn.value,
    "--database", .database_name.value,
    "--region", .aws_region.value,
    "--site-url", .application_url.value] | map(@sh) | join(" "))
]}')"
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters "$PARAMETERS" --query 'Command.CommandId' --output text)"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Code:ResponseCode,Error:StandardErrorContent}'
curl --fail "$APP_URL/readiness.php"
```

Expect `Success`, code `0` and readiness HTTP 200. Open `$APP_URL` and complete the WordPress installer. Use unique demo credentials: HTTP is public and unencrypted.

Optional HTTPS: set both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` before deployment for a new hostname in your existing public Route 53 zone. The stack creates the certificate and DNS records.

## 5. Cleanup

```sh
terraform destroy
```

Review, confirm, and wait for completion. **Database contents and uploads are deleted**, with no final database snapshot. The shared state bucket and DNS zone remain. ALB, NAT, EC2 and RDS incur charges until destroyed.

For troubleshooting, use the SSM command from `terraform output -raw ssm_start_session_command` (Session Manager plugin required) and inspect `/var/log/cloud-init-output.log`. Never print database credentials or make EC2/RDS public.
