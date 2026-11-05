# Private EC2 + WordPress + MySQL

A disposable AWS lab with two explicit stages:

1. **Web:** public Application Load Balancer → private Amazon Linux 2023 EC2, Apache/PHP and real WordPress files. No database exists or is contacted. The page honestly reports that WordPress is not configured.
2. **Database:** add private Single-AZ RDS MySQL, then explicitly configure WordPress through AWS Systems Manager (SSM). Finish the real WordPress installer in your browser.

There is no public EC2 address, SSH, Docker, Kubernetes or deployment wrapper. One NAT Gateway provides outbound package, Git, WordPress and AWS API access. The ALB has two public subnets; the application and two-AZ DB subnet group use private subnets. The application is intentionally one instance, not a highly available WordPress architecture.

## 1. Prepare persistent inputs

Requirements: Terraform `>=1.10,<2`, AWS CLI v2, `jq`, `curl`, an AWS account/identity allowed to create VPC, EC2, ALB, NAT/EIP, IAM, SSM, RDS and Secrets Manager resources. Optional TLS additionally needs ACM and write access to an existing **public, publicly delegated** Route 53 zone. Account restrictions, quotas and available instance classes still apply.

**Publish this implementation to the public repository before launching EC2.** Bootstrap checks out `https://github.com/raelga/kubernetes-talks.git`; unpublished local files cannot be used. Prefer a published commit SHA over `main`. Do not put Git credentials in Terraform or user-data. This lab uses independent state, not the state of the EC2-only lab.

From this directory:

```sh
export AWS_PROFILE=your-profile
cd infra
cp terraform.tfvars.example terraform.tfvars
cp backend.hcl.example backend.hcl
aws sts get-caller-identity
curl -4 https://checkip.amazonaws.com
```

Edit `terraform.tfvars`: set the expected 12-digit account, region, unique `lab_id`, current public IPv4 `/32`, published `repository_ref`, and **persist `enable_database = false`**. The provider rejects a different account. Select an official Amazon Linux 2023 x86_64 image in that region, then **persist its returned AMI ID as `ami_id` before the first apply**:

```sh
aws ec2 describe-images --region YOUR_REGION --owners amazon \
  --filters 'Name=name,Values=al2023-ami-2023.*-kernel-6.1-x86_64' \
    'Name=architecture,Values=x86_64' 'Name=virtualization-type,Values=hvm' \
    'Name=state,Values=available' \
  --query 'sort_by(Images, &CreationDate)[-1].{Id:ImageId,Name:Name,Created:CreationDate}' \
  --output table
```

Replace `YOUR_REGION` with your persisted region. The example AMI placeholder deliberately fails validation: use the actual returned ID, not the placeholder. Keep that same ID through both stages. Terraform does not resolve a moving latest AMI, so a newer published image cannot unexpectedly replace EC2 while you add the database. The default instance is `t3.micro`, with pinned WordPress `7.1.4`. User-data installs PHP 8.3, creates `/opt/infra-lab`, performs Git checkout, verifies the pinned official WP-CLI download, then downloads and verifies WordPress core in `app/public` inside that checkout. There is no fallback site if bootstrap fails.

For HTTPS, set **both** `domain_name` and `hosted_zone_id` to a **new** hostname and your existing zone ID. This creates a regional ACM certificate, a new DNS validation record, an ALB HTTPS listener, HTTP→HTTPS redirect and a new A alias. Existing records are never overwritten; a collision fails instead. Do not reuse a hostname/certificate-validation record owned by another stack. Leave both inputs unset for HTTP only.

All resources incur normal AWS charges, especially the continuously running ALB, NAT, EC2 and RDS. NAT cross-AZ traffic is possible. Budgets/alerts do not stop spending. This is disposable infrastructure, not a production design.

### One stack, separate resource files

All files in `infra/` belong to **one Terraform root and one state**: `network.tf` creates networking/security groups, `ec2.tf` defines the instance and launch data, `db.tf` defines optional MySQL, `alb.tf` contains load balancing/ACM/DNS, and `iam.tf` defines instance permissions. `main.tf` holds shared data/locals. Files are organizational boundaries, not independently applied stacks; do not use `-target` for staging.

### S3 state and locking

Edit ignored `backend.hcl` with your existing private, encrypted, versioned state bucket, its region, expected account and a unique key such as `infra/wordpress/YOUR-LAB-ID/terraform.tfstate`. Both web and database stages **must keep this same key, directory and workspace**. The EC2-only lab needs a different key. Preserve `encrypt = true` and `use_lockfile = true`; never put credentials in backend configuration.

Confirm exact state-key read/write and `.tflock` read/write/delete permissions before initialization. An existing local deployment needs a secure backup and an explicitly reviewed `terraform init -migrate-state -backend-config=backend.hcl`; never force state copying or remove an active lock. The database and application are disposable, but `destroy` does not delete the state bucket. An empty remote state remains a backend consumer.

## 2. Apply and inspect the web stage

```sh
terraform init -backend-config=backend.hcl
terraform plan -out=web.tfplan
terraform apply web.tfplan
export AWS_REGION="$(terraform output -raw aws_region)"
export AWS_DEFAULT_REGION="$AWS_REGION"
INSTANCE_ID="$(terraform output -raw instance_id)"
APP_URL="$(terraform output -raw application_url)"
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[].{Id:InstanceId,Ping:PingStatus}'
```

Wait until SSM reports `Online`, then inspect bootstrap explicitly. SSM commands run as root, and neither bootstrap nor this command contacts MySQL:

```sh
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters '{"commands":["cloud-init status --wait","systemctl is-active httpd php-fpm"]}' \
  --query 'Command.CommandId' --output text)"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Code:ResponseCode,Output:StandardOutputContent,Error:StandardErrorContent}'
curl -i "$APP_URL/"
curl -i "$APP_URL/health.php"
curl -i "$APP_URL/readiness.php"
aws elbv2 describe-target-health --target-group-arn "$(terraform output -raw target_group_arn)"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Private:PrivateIpAddress,Public:PublicIpAddress}'
```

Expected: the root page says files ready/database not configured, `/health.php` returns 200 with `database_checked:false`, `/readiness.php` returns **503**, and the instance has no public address. ALB target health is web liveness, not proof of a configured or installed application. Allow bootstrap and ALB health checks to complete before interpreting responses. HTTP redirects to HTTPS only when domain inputs are supplied. A stale client IP causes requests to time out: update the persisted `/32` and apply.

For diagnosis, use `aws ssm start-session --target "$INSTANCE_ID"` (requires the local Session Manager plugin). Inspect `/var/log/cloud-init-output.log`, `systemctl status httpd php-fpm`, and Apache logs. Do not print private application configuration or database credentials.

## 3. Add the database without replacing the web tier

Confirm the desired release/class is offered in your selected region/account before editing. The explicit defaults are MySQL `8.4.11` and `db.t4g.micro`; these are inputs, not universal availability claims:

```sh
aws rds describe-db-engine-versions --engine mysql --engine-version 8.4.11 \
  --query 'DBEngineVersions[].{Version:EngineVersion,Status:Status}'
aws rds describe-orderable-db-instance-options --engine mysql --engine-version 8.4.11 \
  --db-instance-class db.t4g.micro \
  --query 'OrderableDBInstanceOptions[?StorageType==`gp3`].{Class:DBInstanceClass,Storage:StorageType,Vpc:Vpc}'
```

Edit `terraform.tfvars` to **persist `enable_database = true`**; adjust `mysql_engine_version`/`database_instance_class` if needed. Do not change the persisted AMI ID, Git ref, WordPress version or instance size in this stage.

```sh
terraform plan -out=database.tfplan
terraform show database.tfplan
```

Review that this only adds RDS, its subnet group/security rules, and the exact-secret IAM policy/outputs. **Do not apply a plan replacing EC2, ALB, NAT/EIP or existing networking just to add MySQL.** Those resources do not depend on database inputs. The app security group gains a MySQL egress rule without replacing the instance. Independently changing the persisted AMI ID, repository ref or bootstrap inputs can legitimately produce an EC2 replacement; review every plan.

```sh
terraform apply database.tfplan
terraform output database_endpoint
terraform output database_name
terraform output database_secret_arn
```

RDS is private, encrypted, 20 GiB gp3, Single-AZ, and accepts port 3306 only from the app security group. RDS manages the master password in Secrets Manager; Terraform never obtains its value. The instance role can retrieve **only this DB's exact master secret ARN**, and that permission is added in place after DB creation. WordPress never uses the master as its permanent user.

## 4. Explicitly configure WordPress through SSM

This is a separate, visible action, not Terraform provisioner execution. The payload contains only nonsecret identifiers. `configure.php` retrieves the master secret inside EC2, uses verified RDS TLS, creates/reuses `wordpress_app` with privileges limited to the `wordpress` database, and generates its password locally. The private password and stable salts remain root-owned in `/etc/infra-lab/database.json` (0600). The generated WordPress config is root:apache 0640, outside the public document root. Master credentials are not written to disk or printed. Configuration errors deliberately omit exception text that could expose SQL/passwords.

```sh
DB_ENDPOINT="$(terraform output -raw database_endpoint)"
DB_NAME="$(terraform output -raw database_name)"
DB_SECRET_ARN="$(terraform output -raw database_secret_arn)"
APP_URL="$(terraform output -raw application_url)"
PARAMETERS="$(jq -cn \
  --arg endpoint "$DB_ENDPOINT" --arg database "$DB_NAME" \
  --arg secret "$DB_SECRET_ARN" --arg region "$AWS_REGION" --arg url "$APP_URL" \
  '{commands:[(["php", "/opt/infra-lab/repository/course/infra/labs/wordpress/app/configure.php", "--endpoint", $endpoint, "--secret-arn", $secret, "--database", $database, "--region", $region, "--site-url", $url] | map(@sh) | join(" "))]}')"
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
  --parameters "$PARAMETERS" --query 'Command.CommandId' --output text)"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Code:ResponseCode,Output:StandardOutputContent,Error:StandardErrorContent}'
curl -i "$APP_URL/readiness.php"
curl -IL "$APP_URL/"
```

Require `Success`/response code 0. Initial IAM propagation can take time: after checking inputs and RDS availability, repeat **the same explicit command** if needed. It is idempotent: it preserves the app password/salts, reestablishes its grants, does not drop tables or erase posts, and refuses an endpoint/database mismatch with existing local credentials. Never pass passwords to `send-command`, `wp` arguments, environment variables captured in command logs, or Terraform.

Open `$APP_URL` and complete the actual WordPress browser installer: choose the site name, a non-default administrator username and a strong unique password. **HTTP mode is only a temporary `/32`-restricted demo: the browser installer/login sends credentials unencrypted. Prefer the optional ACM HTTPS hostname; do not reuse these credentials elsewhere.** Credentials typed into the browser are not SSM command output. Do not put them in repository files or screenshots.

After installation, visit the homepage, `/wp-admin/`, create and publish a post, upload an image and reload it. `/readiness.php` reports `installer-ready` after DB configuration and `installed` once WordPress tables exist; it returns 503 while unconfigured or unable to connect. The DB is real; there is no substitute application. Only uploads are writable by Apache. Plugin/theme editing and installs through WordPress are disabled; core/application updates are deliberate pinned-source changes.

If you later enable or change the HTTPS hostname, review/apply the TLS-only plan and **repeat this same configure command with the new `application_url`**. The domain is not embedded in user-data, so adding a certificate does not replace EC2. WordPress trusts `X-Forwarded-Proto` from its only permitted HTTP peer (the ALB), sets HTTPS correctly, and uses the supplied canonical URL to avoid redirect loops.

### Configuration API

```text
php app/configure.php --endpoint HOST --secret-arn ARN --database NAME --region REGION --site-url http[s]://HOST
```

Run as root on the instance; arguments are mandatory nonsecret identifiers. Exit 0 means the restricted database connection and private config were established; exit 1 is a generic, credential-safe failure. It does not run the WordPress site installer. Root state stays on the encrypted delete-on-termination volume, so EC2 replacement loses uploads/local credentials unless you intentionally back them up. Replacement can configure a new dedicated password for the existing DB; it must be explicitly initialized again. This lab has no durable-media architecture or production recovery promise.

## 5. Destroy and verify absence

**Destructive:** backup retention is zero, deletion protection is off, `skip_final_snapshot = true`, and automated backups are deleted. Destroy permanently removes posts, users, uploaded media, DB master secret, EC2/root disk, ALB, NAT/EIP, IAM, VPC/subnets and owned certificate/DNS records. It leaves your existing DNS zone intact. Do not merely switch the database flag back to false unless you intend to delete its data.

Capture the nonsecret identifiers in your current terminal before destruction:

```sh
STACK="$(terraform output -raw stack_name)"
VPC_ID="$(terraform output -raw vpc_id)"
ALB_ARN="$(terraform output -raw alb_arn)"
NAT_ID="$(terraform output -raw nat_gateway_id)"
EIP_ALLOCATION="$(terraform output -raw nat_eip_allocation_id)"
ROLE_NAME="$(terraform output -raw instance_role_name)"
CERT_ARN="$(terraform output -json | jq -r '.certificate_arn.value // empty')"
ZONE_ID="$(terraform output -json | jq -r '.hosted_zone_id.value // empty')"
DOMAIN="$(terraform output -json | jq -r '.domain_name.value // empty')"
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
terraform state list
aws rds describe-db-instances \
  --query "DBInstances[?DBInstanceIdentifier=='$STACK'].{Id:DBInstanceIdentifier,Status:DBInstanceStatus}"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name}'
aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN"
aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT_ID" \
  --query 'NatGateways[].{Id:NatGatewayId,State:State}'
aws ec2 describe-addresses --allocation-ids "$EIP_ALLOCATION"
aws ec2 describe-vpcs --vpc-ids "$VPC_ID"
aws iam get-role --role-name "$ROLE_NAME"
if [ -n "$CERT_ARN" ]; then aws acm describe-certificate --certificate-arn "$CERT_ARN"; fi
if [ -n "$DB_SECRET_ARN" ]; then aws secretsmanager describe-secret --secret-id "$DB_SECRET_ARN"; fi
if [ -n "$ZONE_ID" ]; then
  aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
    --query "ResourceRecordSets[?Name=='$DOMAIN.' || contains(Name, '$DOMAIN.')].{Name:Name,Type:Type}"
fi
```

Expected: empty Terraform state/RDS list; EC2 terminated (eventually absent); ALB, EIP, VPC, role, certificate and managed secret not found; NAT deleted (then eventually absent); no owned hostname/validation records. Route 53 zone still exists. Run commands individually: expected AWS not-found errors are evidence of deletion, not reasons to stop checking the remaining services. NAT/EC2 removal is asynchronous; query again until deleted/terminated. If stopping after the web stage, `DB_SECRET_ARN` is unset and there is no RDS/master secret to check. Investigate any remaining active resources before discarding the local state. Never commit state, plans, private tfvars, captured credentials or generated instance configuration.

## Sources

- [WordPress stable release catalog](https://api.wordpress.org/core/version-check/1.7/) and [core checksum verification](https://developer.wordpress.org/cli/commands/core/verify-checksums/).
- [Official WP-CLI downloads and verification](https://make.wordpress.org/cli/handbook/guides/installing/) and [pinned release metadata](https://api.github.com/repos/wp-cli/wp-cli/releases/tags/v2.12.0).
- [RDS managed master passwords](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html) and [RDS TLS certificates](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html).
