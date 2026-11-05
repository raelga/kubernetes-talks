# Teaching EC2 basics

## Demo flow

Follow the [README](README.md): deploy, open the page, connect over SSH, inspect user-data and security groups, restrict SSH to your IP, then destroy.

## What to emphasize

- Reuse Academy's existing default VPC/public subnet and `vockey`; do not create IAM roles, shared networks or keys for the lab.
- The Amazon Linux login is `ec2-user`. Download the current Academy PEM; a key from another account/lab does not authenticate.
- User-data runs `infra/install.sh` automatically: packages, `/opt/infra-lab`, Git checkout, Apache. `cloud-init status --wait` observes it; students do not install manually.
- Ports 80/443 stay public. Port 22 is public initially, then `ssh_cidr` restricts only SSH. Allowing 443 does not configure HTTPS.
- Environment variables persist in the terminal; `terraform apply -var=...` affects one invocation. Keep the SSH restriction on later applies.
- Keep provider `default_tags` values known at plan time. The random `Stack` tag belongs on resources; using it in provider defaults caused an initial-apply inconsistency.

## Troubleshooting and cleanup

Installation takes time. Check the EC2 system log or `/var/log/infra-lab-bootstrap.log`; EC2 running is not proof that Apache is ready. The base AMI may log SSM credential warnings because this lab deliberately needs no SSM instance role.

SG propagation and tracked connections can delay an access change. Check the actual SSH CIDR and use a new connection rather than assuming an existing session must close.

Use `terraform destroy` at the end. Only the lab's instance, disk and security group are deleted; the default VPC/subnets, Academy key and shared backend stay.
