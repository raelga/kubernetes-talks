# Infrastructure labs

Provision resources, inspect the application separately, then remove the deployment.

| Lab | Infrastructure | Application |
| --- | --- | --- |
| [AWS: Terraform state backend](labs/aws/00-terraform-state/README.md) | Create the shared private S3 state bucket; migrate its own state from local to S3 | No application |
| [AWS: EC2 basics](labs/aws/01-ec2-basics/README.md) | One public EC2 in the default VPC, a security group and user-data | Apache serves the checked-out static page |
| [AWS: WordPress](labs/aws/02-wordpress/README.md) | Public ALB, private EC2, NAT and private RDS MySQL | One `./deploy.sh` command; MySQL provider creates a least-privilege app user; its secret stays outside Terraform state |
| [Azure and GCP](labs/azure-gcp/README.md) | Optional independent provider deployments | Offline response comparison and a small HTTP service |
| [GCP: CLI and project setup](labs/gcp/README.md) | Install the CLI and select an approved project | No deployment required |

EC2 basics separates `infra/` from its static `app/`. WordPress installs the official application directly under `/var/www/html`; a cron job atomically refreshes a separate MySQL application secret from Secrets Manager. The MySQL provider reaches private RDS through a temporary SSM port-forward; no SSH or public MySQL ingress is required.

Start with the state bucket lab: create an unversioned bucket in `local/`, copy state to `remote/`, migrate, then apply versioning and deletion protection. The lab uses Cloud Control for Academy compatibility. EC2 and WordPress reuse the bucket. Backends have fixed keys; initialization needs only the bucket name. Credentials come from AWS configuration; `aws_region` defaults to `us-east-1`.

For another region, set `TF_VAR_aws_region` before deployment and add `-backend-config="region=$TF_VAR_aws_region"` to backend initialization. S3 backends cannot reference Terraform variables directly.

EC2 basics keeps web ports 80/443 public and starts SSH public; a follow-up variable restricts SSH only to your IP. The basic app serves HTTP, not HTTPS. WordPress adds the public ALB → private EC2 → private RDS chain and optional ACM HTTPS. Use demo data only.

## Run safely

- Check the AWS account and region. Use one bucket per learner and one deployment of each lab per bucket.
- Review every plan. Keep databases private, restrict SSH to your IP after the exercise, and never put credentials in Git, user-data or command output.
- EC2, public IPv4 and storage incur charges. WordPress also adds ALB, NAT and RDS charges; this is not a highly available production design.
- Run the WordPress lab's `./destroy.sh` to remove its SQL user before RDS and the rest of the application stack. Keep the shared state bucket for the other labs.
- Keep state, plans, private variables, credentials and real captures outside Git. Do not delete shared DNS zones, backends or unrelated resources.

Fixtures are synthetic and do not prove live cloud correctness. Offline checks never deploy resources. Reviewed dependency lockfiles may be committed.

## References

- [Terraform introduction](https://developer.hashicorp.com/terraform/intro)
- [Terraform module catalog](https://registry.terraform.io/browse/modules)
