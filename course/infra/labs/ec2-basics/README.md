# Private EC2 behind an Application Load Balancer

Deploy a real static Apache application from a public Git checkout. The public ALB accepts only your IPv4 `/32`; it forwards HTTP to one **private EC2 instance with no public IP and no SSH**. One NAT Gateway provides outbound package, Git and Session Manager connectivity. There is no database, S3, Python, Docker or Kubernetes.

```text
Your public IPv4 /32 → public ALB (two availability zones) → private EC2:80
                                                           ↓ outbound HTTP/HTTPS
                                                  NAT Gateway → Internet Gateway
```

Two public and two private subnets span two availability zones. EC2 runs in the first private subnet; the second private subnet illustrates the network layout, not redundant compute. The single NAT Gateway is in the first public subnet: it is not highly available, and traffic from the other zone can incur cross-zone charges. ALB → EC2 remains HTTP even when public HTTPS is enabled.

## 1. Prerequisites and configuration

Use Terraform `>=1.9,<2`, AWS CLI v2, curl and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html). Authenticate with authorized AWS credentials. Your identity needs permissions for VPC/networking, EC2, ELB, IAM roles and instance profiles, `iam:PassRole`, and SSM sessions; optional TLS also requires ACM and access to the selected Route 53 zone. Do not bypass account restrictions. Two available zones, a permitted `t3.micro` (or another x86_64 type), NAT/EIP and ALB quotas are required.

From the repository root:

```sh
cd course/infra/labs/ec2-basics/infra
aws sts get-caller-identity
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `account_id`: the authorized 12-digit account. `allowed_account_ids` rejects other accounts.
- `aws_region`: your authorized region. The AMI lookup selects the latest official Amazon Linux 2023 x86_64 image there.
- `lab_id`: a unique 3–20 character lowercase label, starting with a letter.
- `client_cidr`: your actual public outbound IPv4 followed by `/32`; the example address will not work.
- `repository_ref`: preferably a **full published commit SHA containing this lab**. The default is `main`, which can change. Unpublished local changes cannot be fetched by EC2. Publish the complete lab before applying.

This deployment uses new independent local state in `infra/`; never copy old lab state into it or migrate an existing deployment with this configuration. Keep credentials, local variables, plans and state out of Git. Random suffixes distinguish independent stacks; no shared Terraform modules or existing resources are adopted.

### Optional HTTPS with ACM

Leave `domain_name` and `hosted_zone_id` unset for HTTP only. An ALB DNS name alone cannot use this lab's public ACM certificate. To enable HTTPS, set **both** to a new hostname and an existing, publicly delegated Route 53 hosted zone containing it. The provider requests a regional ACM certificate, creates its DNS-validation CNAME, attaches it to the ALB's port 443 listener, redirects port 80 to the hostname, and creates an A alias.

Use a fresh hostname. Both DNS resources set `allow_overwrite = false`: existing application or validation records cause an error, not takeover. The lab deletes only its own alias, validation record and certificate; it never deletes the shared hosted zone. DNS must be publicly resolvable for certificate validation. DNS inputs are not embedded in user-data, so enabling TLS does not replace EC2 just to change its hostname.

## 2. Initialize, inspect and apply

```sh
terraform init
terraform workspace show
terraform validate
terraform plan -out=apply.tfplan
terraform show apply.tfplan
terraform apply apply.tfplan
terraform output
```

Read the saved plan before applying. Expect a new VPC, four subnets, Internet Gateway, one NAT/EIP, routes, two security groups, ALB/target group/listener, one EC2 instance, encrypted 8 GiB gp3 root disk, and a role/profile with `AmazonSSMManagedInstanceCore`. With DNS inputs, expect the certificate, validation, HTTPS listener and two DNS records too. There must be no public EC2 IP, SSH rule or blanket inbound access. A default **route** is necessary; it is not an inbound rule.

Security groups are separate: ALB inbound TCP 80 (plus 443 with TLS) only from `client_cidr`; ALB outbound TCP 80 only to the app security group; app inbound TCP 80 only from the ALB security group. App outbound TCP 80/443 goes through NAT; TCP/UDP 53 is scoped to the VPC. Amazon's VPC resolver has its own DNS filtering semantics; security groups are not a DNS firewall. Responses use stateful rules. Session Manager is outbound HTTPS, not an inbound SSH tunnel.

## 3. Inspect the application and bootstrap

```sh
APPLICATION_URL=$(terraform output -raw application_url)
curl --fail --show-error "$APPLICATION_URL/health"
curl --fail --show-error "$APPLICATION_URL/"
curl --fail --show-error "$APPLICATION_URL/runtime.json"
aws elbv2 describe-target-health --target-group-arn "$(terraform output -raw target_group_arn)" --region "$(terraform output -raw aws_region)"
aws ec2 get-console-output --instance-id "$(terraform output -raw instance_id)" --region "$(terraform output -raw aws_region)" --latest --query Output --output text
aws ssm start-session --target "$(terraform output -raw instance_id)" --region "$(terraform output -raw aws_region)"
```

EC2 `running` is not application readiness. Until cloud-init and the ALB health checks finish, requests may return 503. `/health` returns HTTP 200 with `ready`; the page displays the server hostname and actual checked-out commit, not credentials or instance metadata. Bootstrap fails rather than publishing a fake fallback if checkout or application files are unavailable.

Inside the SSM session:

```sh
sudo cloud-init status --long
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/infra-lab-bootstrap.log
sudo journalctl -u httpd -u amazon-ssm-agent --no-pager
sudo find /opt/infra-lab -maxdepth 2 -type d
sudo git -C /opt/infra-lab/repository rev-parse HEAD
sudo cat /opt/infra-lab/repository/course/infra/labs/ec2-basics/app/runtime.json
curl --fail http://localhost/health
exit
```

The inline EC2 user-data installs packages, explicitly creates `/opt/infra-lab`, fetches the requested Git ref and checks out a detached commit. Apache serves the checked-out `course/infra/labs/ec2-basics/app/` directory directly; bootstrap adds only public `runtime.json` information. Logs go to cloud-init, `/var/log/infra-lab-bootstrap.log` and the system console. No wrapper script is required. The SSM role is for instance management only; the static application does not call AWS APIs. IMDSv2 is required.

If requests fail, inspect target health and bootstrap logs, verify the published ref, current public `/32`, routes/NAT and SSM permissions. Do not add SSH, assign a public IP or widen inbound access. Changing `repository_ref` changes user-data and **replaces EC2**, deleting its old root disk. Review a new plan before applying; a moving branch does not automatically update an existing instance. A newer AMI discovered on a later plan can also replace EC2.

## 4. Destroy and verify provider-side absence

Keep the same `infra/` directory, workspace and state. Save identifiers before destruction:

```sh
AWS_REGION=$(terraform output -raw aws_region)
STACK=$(terraform output -raw stack_name)
VPC_ID=$(terraform output -raw vpc_id)
INSTANCE_ID=$(terraform output -raw instance_id)
NAT_ID=$(terraform output -raw nat_gateway_id)
ALB_ARN=$(terraform output -raw alb_arn)
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)
EIP_ID=$(terraform output -raw nat_eip_allocation_id)
ROLE_NAME=$(terraform output -raw instance_role_name)
terraform output -json > outputs.before-destroy.local.json
```

If HTTPS is enabled, also save these before destruction:

```sh
CERTIFICATE_ARN=$(terraform output -raw certificate_arn)
DOMAIN_NAME=$(terraform output -raw domain_name)
HOSTED_ZONE_ID=$(terraform output -raw hosted_zone_id)
VALIDATION_NAME=$(terraform output -raw dns_validation_record_name)
```

Then inspect and apply the destruction plan:

```sh
terraform workspace show
terraform state list
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
terraform state list
```

The final state list must be empty. Also query AWS with the saved identifiers; empty Terraform state alone is not proof of cleanup:

```sh
aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Vpcs[].VpcId'
aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId'
aws ec2 describe-route-tables --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[].RouteTableId'
aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[].GroupId'
aws ec2 describe-network-interfaces --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[].NetworkInterfaceId'
aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId'
aws ec2 describe-addresses --region "$AWS_REGION" --filters "Name=allocation-id,Values=$EIP_ID" --query 'Addresses[].AllocationId'
aws ec2 describe-volumes --region "$AWS_REGION" --filters "Name=tag:Stack,Values=$STACK" --query 'Volumes[].VolumeId'
aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter "Name=nat-gateway-id,Values=$NAT_ID" --query 'NatGateways[?State!=`deleted`].NatGatewayId'
aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INSTANCE_ID" --query 'Reservations[].Instances[].State.Name'
aws elbv2 describe-load-balancers --region "$AWS_REGION" --load-balancer-arns "$ALB_ARN"
aws elbv2 describe-target-groups --region "$AWS_REGION" --target-group-arns "$TARGET_GROUP_ARN"
aws iam get-role --role-name "$ROLE_NAME"
aws iam get-instance-profile --instance-profile-name "$ROLE_NAME"
```

Expect `[]` from the network, address, disk and active-NAT queries. EC2 must be `terminated` or return `InvalidInstanceID.NotFound`, never merely stopped. ELB queries must return the specific `LoadBalancerNotFound` / `TargetGroupNotFound` errors; IAM queries must return `NoSuchEntity`. These deliberately checked not-found responses are expected, unlike authentication or authorization errors. AWS may retain a deleted NAT or terminated instance in read-only history.

For HTTPS deployments, also check:

```sh
aws acm describe-certificate --region "$AWS_REGION" --certificate-arn "$CERTIFICATE_ARN"
aws route53 list-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --query "ResourceRecordSets[?Name=='${DOMAIN_NAME%.}.' || Name=='${VALIDATION_NAME%.}.']"
```

Expect ACM `ResourceNotFoundException` and no matching owned records (`[]`). The shared zone must remain. Keep private state and saved IDs until absence is established. Expired credentials, `AccessDenied`, other query failures or resources still deleting are **not** successful verification. Never erase state to conceal resources or delete another deployment's resources.

## Costs and scope

ALB, NAT Gateway, public IPv4, EC2, disks and traffic can all incur charges even with no visitors; do not assume a free tier. A NAT Gateway and ALB can cost more than this micro instance. Check AWS Billing/Cost Explorer filters, budgets and alerts, then destroy the whole stack when finished: stopping EC2 leaves networking and storage charges. Billing is delayed, and budget alerts do not automatically stop spending. This is disposable single-instance infrastructure, not a production availability or backup design.
