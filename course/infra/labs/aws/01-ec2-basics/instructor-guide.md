# Teaching the EC2 lab

Follow the [README](README.md). The goal is to connect Terraform infrastructure, automatic installation and security groups.

## What to show

1. The plan creates networking, a public ALB and private EC2.
2. User-data runs [`infra/install.sh`](infra/install.sh) automatically. Students do not install Apache manually.
3. Open the application and point out its hostname and Git commit.
4. Inspect the security groups: internet → ALB → EC2. Only the ALB security group can reach EC2 port 80.
5. Run `terraform destroy` and wait for completion. The shared state bucket stays.

## What students should notice

- A running instance is not necessarily a ready application. Bootstrap and health checks take time.
- The ALB is public; EC2 has no public IP or SSH access.
- Infrastructure lives in `infra/`; the served files live in `app/`.

## If the page does not load

Use the optional SSM/log instructions in the README. Check bootstrap and target health before changing network rules. Do not add SSH or make EC2 public.

ALB and NAT keep charging while they exist. Finish with destroy, not just stopping the instance.
