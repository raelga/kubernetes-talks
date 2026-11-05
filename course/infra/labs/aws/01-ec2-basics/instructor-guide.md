# Teaching the EC2 basics lab

## Demo flow

Follow the [README](README.md): deploy one EC2, open its public IP, inspect the security group and user-data, then destroy.

## Key points

- Public subnet + Internet Gateway + public IP provide connectivity; the security group controls allowed traffic.
- HTTP port 80 is open; SSH is not. Outbound access lets package installation and Git checkout work. Security groups are stateful.
- User-data runs `infra/install.sh` automatically. Point out package installation, `/opt/infra-lab` and the Git checkout.
- No ALB, NAT Gateway, IAM instance role or database is needed. WordPress introduces the private tiers later.

## Troubleshooting and cleanup

If the page is not ready, check the instance system log in the EC2 console. Installation takes time; EC2 running does not mean Apache is ready.

Finish with `terraform destroy`. The shared state bucket remains. EC2, public IPv4 and disk storage cost money until removed.

If replacing the earlier ALB-based version, review the destructive plan: old load balancer/NAT/private-tier resources are removed and EC2 is replaced. Do not apply without reviewing those changes.
