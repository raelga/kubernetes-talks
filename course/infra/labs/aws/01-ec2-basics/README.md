# Private EC2 behind an ALB

Deploy Apache from this public repository to a private EC2 instance: no public instance IP or SSH. A public ALB accepts HTTP/HTTPS from any IPv4 client; a NAT Gateway provides outbound access. Apache serves [`app/`](app/) directly. EC2 accepts application traffic only from the ALB security group.

## 1. Set inputs

Use Terraform `>=1.10,<2`, AWS CLI v2 and curl. Configure your authorized AWS credentials and region using your normal environment/profile. Both Terraform's provider and S3 backend inherit that configuration.

Complete [Terraform state backend](../00-terraform-state/README.md) first, including its state migration. From the repository root:

```sh
cd course/infra/labs/aws/01-ec2-basics/infra
aws sts get-caller-identity
```

Inspect the identity and confirm the account is authorized, then:

```sh
STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
```

The optional `TF_VAR_lab_id` defaults to `ec2-basics`; override it for a separate deployment with a unique 3–20 character lowercase ID starting with a letter. Keep any overrides and the same backend key/workspace through cleanup. Recover an existing ID with `terraform output -raw lab_id` after initializing its original key.

The Git ref defaults to `main`. Optionally export `TF_VAR_repository_ref` to a full **published** commit SHA containing this lab; EC2 cannot fetch unpublished local changes.

Optional HTTPS: export both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a new hostname in an existing publicly delegated Route 53 zone. Existing DNS records are never overwritten. Without both inputs, use HTTP; the ALB-to-EC2 connection remains HTTP.

## 2. Deploy

```sh
terraform init \
  -backend-config="bucket=$STATE_BUCKET" \
  -backend-config="key=aws/ec2-basics/${TF_VAR_lab_id:-ec2-basics}/terraform.tfstate"
terraform plan -out=apply.tfplan
terraform show apply.tfplan
terraform apply apply.tfplan
```

Review the plan before applying. The backend enables encryption and native S3 locking; your identity needs state-key read/write and `.tflock` read/write/delete access. Never reuse another stack's key. For an existing local deployment, back up state and explicitly review migration using `terraform init -migrate-state` with these same backend arguments; do not create a duplicate stack or bypass locks.

User-data automatically runs the tracked [`infra/install.sh`](infra/install.sh) once at launch. It installs packages, fetches the selected Git ref, configures Apache and records the actual commit in `runtime.json`. **No manual installation commands are needed.** Script/ref changes replace EC2 and its root disk; a later latest-AMI lookup may also replace it. Review every plan.

## 3. Open the application

Allow cloud-init and ALB health checks to finish; early requests may return 503.

```sh
APPLICATION_URL="$(terraform output -raw application_url)"
printf '%s\n' "$APPLICATION_URL"
curl --fail --show-error "$APPLICATION_URL/health"
```

Open the URL in your browser. `/health` returns `ready`; the page shows the hostname and checked-out commit. Bootstrap fails rather than serving a fake fallback.

Optional troubleshooting: run the command printed by `terraform output -raw ssm_start_session_command` (requires the Session Manager plugin), then inspect `sudo cat /var/log/cloud-init-output.log`. Do not add SSH, a public instance IP or wider inbound rules.

## 4. Understand the security groups

Inspect the ALB and EC2 security groups in the AWS console. The ALB permits internet clients (`0.0.0.0/0`) on HTTP port 80 and, when HTTPS is configured, port 443. It forwards application traffic and health checks to private EC2 on port 80.

EC2's inbound HTTP rule references the **ALB security group**, not a client IP range. EC2 has no public IP or SSH access. Keep the ALB public and the EC2 rule restricted to the ALB security group; restricting EC2 to your own public IP would block ALB forwarding.

## 5. Cleanup

From the same directory with the same shell inputs, backend and workspace:

```sh
terraform destroy
```

Review the proposed deletions, confirm, and wait for successful completion. This removes this stack's managed resources, not unrelated AWS resources. The shared state bucket and existing Route 53 zone remain.

ALB, NAT, public IPv4, EC2, disks and traffic incur charges. Stopping EC2 is not cleanup. Check costs and destroy when finished; billing is delayed and budget alerts do not stop spending. This is a disposable single-instance lab, not production infrastructure.
