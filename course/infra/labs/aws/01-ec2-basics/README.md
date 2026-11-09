# EC2 basics: Security Groups and User Data

Deploy one EC2 in Academy's existing default VPC. User-data installs Apache and checks out the application automatically. No ALB, NAT Gateway or new IAM role.

Terraform renders [`infra/install.sh`](infra/install.sh) directly as user-data with `templatefile`; cloud-init executes it on first boot.

Terraform randomly selects a default subnet, choosing its Availability Zone. The selection stays in state across applies.

You need Terraform `>=1.10,<2`, AWS CLI v2, curl, an SSH client, and the completed [state bucket lab](../00-terraform-state/README.md). Use your configured Academy credentials; the region defaults to `us-east-1`. Academy must provide a default VPC/public subnet and the `vockey` SSH key pair.

## 1. Deploy

From the repository root, enter the Terraform directory.

```sh
cd course/infra/labs/aws/01-ec2-basics/infra
```

Read the shared bucket name from the state lab and save it for initialization.

```sh
export STATE_BUCKET="$(terraform -chdir=../../00-terraform-state/remote output -raw state_bucket_name)"
```

Initialize providers and the S3 backend. Its fixed key is `ec2-basics/terraform.tfstate`.

```sh
terraform init -backend-config="bucket=$STATE_BUCKET"
```

Preview the changes. The default VPC/subnet are read, not created or managed by this stack.

```sh
terraform plan
```

Create EC2 and its security group. Review the plan and enter `yes`.

```sh
terraform apply
```

Print the application URL and open it in your browser. Installation takes a little longer than instance creation.

```sh
terraform output -raw application_url
```

The page shows the hostname and checked-out commit. HTTP and SSH are public initially; use demo data only. Port 443 is also allowed by the security group, but this basic app does not configure HTTPS or a certificate.

## 2. Inspect user-data over SSH

Download the **current Academy key for `vockey`** to `~/.ssh/labsuser.pem`. A key from another lab/account will not work. Restrict its local file permissions.

```sh
chmod 600 ~/.ssh/labsuser.pem
```

Connect as Amazon Linux's `ec2-user`. Accept the host fingerprint after checking the instance address.

```sh
ssh -i ~/.ssh/labsuser.pem ec2-user@"$(terraform output -raw public_ip)"
```

Inside EC2, wait for the automatic installation to finish. This observes user-data; it does not install anything manually.

```sh
sudo cloud-init status --wait
```

Check that Apache is running. Expect `active`.

```sh
systemctl is-active httpd
```

Read the hostname and commit written by [`infra/install.sh`](infra/install.sh) after its Git checkout.

```sh
cat /opt/infra-lab/repository/course/infra/labs/aws/01-ec2-basics/app/runtime.json
```

Return to your local terminal before running more Terraform commands.

```sh
exit
```

## 3. Understand the security group

Inspect the managed security group and its rules.

```sh
terraform state show aws_security_group.app
```

- **80/443:** public web access (`0.0.0.0/0`).
- **22:** public by default, controlled by `ssh_cidr`.
- **Outbound:** package downloads and Git checkout.
- Security groups are stateful: replies to allowed connections are permitted automatically.

The default public subnet and Internet Gateway provide connectivity; the security group decides which traffic is allowed.

## 4. Restrict SSH to your IP

Set `ssh_cidr` to your current public IPv4 address. HTTP/HTTPS stay public.

```sh
export TF_VAR_ssh_cidr="$(curl -4 -fsS https://checkip.amazonaws.com)/32"
```

Preview the change. Only the SSH rule should change—not EC2 or the web rules.

```sh
terraform plan
```

Apply the restriction and confirm with `yes`. New SSH connections are allowed from your IP; existing tracked connections can persist.

```sh
terraform apply
```

**Alternative:** instead of exporting the variable, pass it for one command:

```sh
terraform apply -var="ssh_cidr=$(curl -4 -fsS https://checkip.amazonaws.com)/32"
```

`-var` applies only to that invocation. Keep the environment export for later applies, or repeat the flag, otherwise SSH returns to its public default. If your public IP changes, update the value and apply again.

## 5. Cleanup

Delete this stack's EC2, disk and security group. Review, confirm, and wait for completion.

```sh
terraform destroy
```

The default VPC/subnets, Academy key pair and shared state bucket remain. EC2, public IPv4 and disk storage incur charges while they exist. Use one deployment of this lab per state bucket.

For startup problems, inspect the EC2 console system log or `/var/log/infra-lab-bootstrap.log` over SSH. Rebooting does not rerun user-data; changing this lab's user-data replaces EC2.
