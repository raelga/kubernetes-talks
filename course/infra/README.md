# Infrastructure labs

Provision resources, inspect the application separately, then remove the deployment.

| Lab | Infrastructure | Application |
| --- | --- | --- |
| [AWS: Terraform state backend](labs/aws/00-terraform-state/README.md) | Create the shared private S3 state bucket; migrate its own state from local to S3 | No application |
| [AWS: EC2 basics](labs/aws/01-ec2-basics/README.md) | Public load balancer, private EC2 and outbound NAT | Static Apache site; inspect launch-time directory creation and Git checkout |
| [AWS: WordPress](labs/aws/02-wordpress/README.md) | The same network pattern, then optional private RDS MySQL | Deploy the web host first, add the database, then explicitly configure WordPress |
| [Azure and GCP](labs/azure-gcp/README.md) | Optional independent provider deployments | Offline response comparison and a small HTTP service |

Each AWS application lab separates `infra/` (Terraform resources) from `app/` (application files). EC2 basics user-data runs `infra/install.sh` automatically at launch; no manual installation is needed. READMEs separate deployment steps from optional troubleshooting. Enabling the WordPress database does not replace the web host.

Start with the AWS Terraform state lab: create one S3 bucket locally, then migrate that root's state into its bucket. EC2 basics follows; WordPress comes next. Both reuse the bucket with separate state keys and native S3 locking. The labs inherit your configured AWS region, take deployment inputs through `TF_VAR_…` environment variables, and pass bucket/key arguments directly to `terraform init`; no copied tfvars or backend settings files are needed. WordPress keeps the same key across its web/database stages. Application destruction leaves the shared bucket intact.

ALB accepts web traffic only from your client IP, EC2 accepts it only from the ALB security group, and MySQL accepts it only from the application security group. Instances and databases have no public IP. Optional ACM HTTPS requires a domain and an existing public Route 53 zone you control; without those inputs the lab uses HTTP.

## Run safely

- Confirm account, region, permissions, quotas and credential expiry. Use a unique lab ID and independent state; never copy another deployment's state.
- Review every plan. Keep databases private, do not open SSH or bypass access restrictions, and never put credentials in Git, user-data or command output.
- ALB, NAT Gateway, public IPv4, EC2, RDS and storage incur charges while running. One NAT Gateway keeps the lab simple; this is not a highly available production architecture.
- Run `terraform destroy` to remove each application stack; review and confirm the deletions. WordPress data is disposable. Keep the shared state bucket for the other labs.
- Keep state, plans, private variables, credentials and real captures outside Git. Do not delete shared DNS zones, backends or unrelated resources.

Fixtures are synthetic and do not prove live cloud correctness. Offline checks never deploy resources. Reviewed dependency lockfiles may be committed.

## References

- [Terraform introduction](https://developer.hashicorp.com/terraform/intro)
- [Terraform module catalog](https://registry.terraform.io/browse/modules)
