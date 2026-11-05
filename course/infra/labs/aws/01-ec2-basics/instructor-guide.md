# Teaching the EC2 lab

## Demo flow

Follow the [README](README.md): plan/apply, open the page, inspect internet → ALB → EC2 security groups, then destroy. Point out the hostname and Git commit on the page.

## Key points

- User-data runs [`infra/install.sh`](infra/install.sh); students do not install Apache manually. Infrastructure is in `infra/`, served files in `app/`.
- EC2 is private with no SSH access. NAT enables outbound installation; only the ALB security group reaches EC2 port 80.
- Check the configured AWS account/profile and region before applying. Review replacement actions when changing the installer, Git ref or AMI.
- HTTP is public and unencrypted. Optional HTTPS uses both `TF_VAR_domain_name` and `TF_VAR_hosted_zone_id` for a new hostname in an existing public Route 53 zone, followed by plan/apply; Terraform creates ACM and DNS validation resources.
- ALB, NAT and EC2 cost money until destroyed. The shared backend bucket and existing DNS zone remain.

## Troubleshooting

Bootstrap and target health checks take time; early HTTP 503 responses do not mean the network is broken. Check ALB target health and `/var/log/cloud-init-output.log`. For private access, use the command from `terraform output -raw ssm_start_session_command` with the Session Manager plugin installed. Do not add SSH or make EC2 public.
