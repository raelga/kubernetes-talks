# Private EC2 + WordPress + MySQL

Deploy WordPress in two stages: first the private EC2 web tier behind a public ALB, then private RDS MySQL without replacing EC2. The ALB accepts HTTP/HTTPS from any IPv4 client; EC2 has no public IP or SSH and accepts application traffic only from the ALB security group. A NAT Gateway provides outbound access.

## 1. Set inputs

Use Terraform `>=1.10,<2`, AWS CLI v2, curl and jq. Configure your authorized AWS credentials and region through your normal environment/profile; Terraform, its S3 backend and the CLI inherit them. Complete [Terraform state backend](../00-terraform-state/README.md), including state migration, first.

From the repository root:

```sh
cd course/infra/labs/aws/02-wordpress/infra
aws sts get-caller-identity
```

Inspect the identity and confirm the account is authorized, then:

```sh
export TF_VAR_enable_database=false
STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
export TF_VAR_ami_id="$(aws ec2 describe-images --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-kernel-6.1-x86_64' \
    'Name=architecture,Values=x86_64' 'Name=virtualization-type,Values=hvm' \
    'Name=state,Values=available' \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)"
```

The optional `TF_VAR_lab_id` defaults to `wordpress`; override it for a separate deployment with a unique 3–20 character lowercase ID starting with a letter. Keep these exported inputs, the **same AMI**, key, directory and workspace through both stages and cleanup. Do not rerun the AMI query between stages. After initializing the original key, recover the ID/AMI with `terraform output -raw lab_id` and `terraform output -raw ami_id`, then export those original values again. Restore the other original inputs too.

The Git ref defaults to `main`; optionally export `TF_VAR_repository_ref` to a full **published** commit SHA containing this lab. EC2 cannot fetch unpublished local files. Defaults are `t3.micro` and WordPress `7.1.4`.

Optional HTTPS: export both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a **new** hostname in your existing public Route 53 zone. Existing records are never overwritten. Otherwise HTTP is used. This is a public demo; never reuse browser credentials elsewhere. ALB-to-EC2 traffic remains HTTP.

## 2. Deploy the web tier

```sh
terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=aws/wordpress/${TF_VAR_lab_id:-wordpress}/terraform.tfstate"
terraform plan -out=web.tfplan
terraform show web.tfplan
terraform apply web.tfplan
INSTANCE_ID="$(terraform output -raw instance_id)"
APP_URL="$(terraform output -raw application_url)"
printf '%s\n' "$APP_URL"
```

Review the plan before applying. The backend enables encryption and native S3 locking; your identity needs state-key read/write and `.tflock` read/write/delete access. Never reuse another stack's key. Existing local state requires a backup and explicitly reviewed `terraform init -migrate-state` with the same arguments, not a duplicate stack or lock bypass.

Bootstrap installs PHP 8.3, checks out this repository, verifies the pinned WP-CLI download and WordPress core, then starts Apache. Wait for bootstrap and ALB health checks before opening the URL. The page should report **files ready/database not configured**; `/health.php` returns 200 and `/readiness.php` returns 503. ALB health is not database readiness.

Optional troubleshooting: run the command from `terraform output -raw ssm_start_session_command` (requires the Session Manager plugin), then inspect `sudo cat /var/log/cloud-init-output.log`. Do not print private config or credentials.

## 3. Understand the security groups

Inspect the ALB and EC2 security groups in the AWS console. Internet clients (`0.0.0.0/0`) reach the ALB on HTTP port 80 and, when HTTPS is configured, port 443. The ALB forwards application traffic and health checks to private EC2 on port 80; EC2's inbound rule references only the **ALB security group**, not a client IP range.

The next stage adds private RDS with MySQL port 3306 allowed only from the **EC2 application security group**. Keep these boundaries: internet → ALB HTTP/HTTPS → EC2 HTTP → RDS MySQL. EC2 has no public IP or SSH; RDS is not publicly accessible. Restricting EC2 to your own public IP would block ALB forwarding.

## 4. Add MySQL

The defaults are MySQL `8.4.11` and `db.t4g.micro`; availability depends on your region/account. If needed, export `TF_VAR_mysql_engine_version` and `TF_VAR_database_instance_class` to offered values.

```sh
export TF_VAR_enable_database=true
terraform plan -out=database.tfplan
terraform show database.tfplan
terraform apply database.tfplan
```

**Do not apply a plan replacing EC2, ALB, NAT or existing networking just to add MySQL.** Keep the AMI, Git ref and other web inputs unchanged. All `infra/*.tf` files form one root and state; do not stage with `-target`.

RDS is private, encrypted, Single-AZ, and accepts MySQL only from the app security group. RDS manages the master password in Secrets Manager; Terraform never reads its value. The instance role gains access only to this database's exact master secret.

## 5. Configure WordPress

Wait until SSM reports the instance `Online`:

```sh
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].{Id:InstanceId,Ping:PingStatus}'
```

Run the explicit configuration step. Its command contains identifiers, never passwords:

```sh
DB_ENDPOINT="$(terraform output -raw database_endpoint)"
DB_NAME="$(terraform output -raw database_name)"
DB_SECRET_ARN="$(terraform output -raw database_secret_arn)"
DEPLOYED_REGION="$(terraform output -raw aws_region)"
APP_URL="$(terraform output -raw application_url)"
PARAMETERS="$(jq -cn \
  --arg endpoint "$DB_ENDPOINT" --arg database "$DB_NAME" \
  --arg secret "$DB_SECRET_ARN" --arg region "$DEPLOYED_REGION" --arg url "$APP_URL" \
  '{commands:[(["php", "/opt/infra-lab/repository/course/infra/labs/aws/02-wordpress/app/configure.php", "--endpoint", $endpoint, "--secret-arn", $secret, "--database", $database, "--region", $region, "--site-url", $url] | map(@sh) | join(" "))]}')"
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters "$PARAMETERS" --query 'Command.CommandId' --output text)"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Code:ResponseCode,Output:StandardOutputContent,Error:StandardErrorContent}'
curl -i "$APP_URL/readiness.php"
```

Require command `Success`/code 0 and readiness HTTP 200. The script fetches the master secret inside EC2, verifies RDS TLS, creates a restricted `wordpress_app` user and keeps its generated password/salts in root-owned `/etc/infra-lab/database.json` (0600). WordPress config is root:apache 0640 outside the public document root. Master credentials are not persisted or printed.

The same explicit command is safe to repeat after checking inputs, RDS availability and IAM propagation: it preserves app credentials/salts and does not erase tables. It rejects an endpoint/database mismatch. Never pass passwords through Terraform, SSM arguments or logs.

Open `$APP_URL` and complete the WordPress browser installer with a unique administrator name and password. Prefer HTTPS: HTTP transmits browser credentials unencrypted. This step installs the actual site; configuration alone does not. EC2 replacement loses uploads/local credentials and requires explicit reconfiguration; this lab has no production backup architecture.

## 6. Cleanup

From the same directory with the same shell inputs, backend and workspace:

```sh
terraform destroy
```

Review the proposed deletions, confirm, and wait for successful completion. **WordPress posts, users, uploads and database data are lost:** backup retention is zero and there is no final snapshot. Switching the database flag back to false also deletes its data.

Destroy removes this stack's managed resources, not unrelated AWS resources. The shared backend bucket and existing Route 53 zone remain. Never commit state, plans, credentials or generated private configuration.

ALB, NAT, EC2, RDS, disks and traffic incur charges. Destroy when finished; stopping EC2 is not cleanup. Billing is delayed and budget alerts do not stop spending.
