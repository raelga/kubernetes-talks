# Infrastructure labs

Provision resources, inspect the application separately, then remove the deployment.

| Lab | Infrastructure | Application |
| --- | --- | --- |
| [AWS: Terraform state backend](labs/aws/00-terraform-state/README.md) | Create the shared private S3 state bucket; migrate its own state from local to S3 | No application |
| [AWS: EC2 basics](labs/aws/01-ec2-basics/README.md) | One public EC2 in the default VPC, a security group and user-data | Apache serves the checked-out static page |
| [AWS: WordPress progression](labs/aws/02-wordpress/README.md) | EC2, RDS, separate states, modules, Auto Scaling, AMIs and S3 | Follow one application from local state to replaceable instances |
| [Azure and GCP](labs/azure-gcp/README.md) | Optional independent provider deployments | Offline response comparison and a small HTTP service |
| [Azure: CLI and labs](labs/azure/README.md) | Azure onboarding, state backend, VM, and WordPress | Optional instructor-account demonstration |
| [GCP: CLI and project setup](labs/gcp/README.md) | Install the CLI and select an approved project | No deployment required |
| [GCP: WordPress module](labs/gcp/03-wordpress-module/README.md) | WordPress and Cloud SQL in a local Terraform module | Separate state from the standalone lab |
| [GCP: WordPress managed group](labs/gcp/04-wordpress-mig/README.md) | One-instance managed group, stable load balancer and Cloud SQL | Compare VM replacement with the single-instance module |

EC2 basics separates `infra/` from its static `app/`. The WordPress progression starts with a local database and introduces RDS, separate Terraform states, modules, Auto Scaling, AMIs and S3 in stages.

The state bucket lab creates a shared S3 backend with versioning and deletion protection. WordPress stages specify whether they use local state or this backend; follow each stage's instructions. Credentials come from AWS configuration.

For a different AWS region, follow the variables and backend initialization instructions in the relevant stage.

EC2 basics serves HTTP and starts SSH public before restricting it to your IP. The WordPress stages also use HTTP for the exercises: restrict access where instructed and use disposable data only.

## Run safely

- Check the AWS account and region. Use one bucket per learner and one deployment of each lab per bucket.
- Review every plan. Keep databases private, restrict SSH to your IP after the exercise, and never put credentials in Git, user-data or command output.
- EC2, public IPv4 and storage incur charges. WordPress also adds ALB, NAT and RDS charges; this is not a highly available production design.
- Destroy the WordPress stack with `terraform destroy` from its lab directory. RDS deletion removes the SQL user with the database. Keep the shared state bucket for the other labs.
- Keep state, plans, private variables, credentials and real captures outside Git. WordPress state and saved plans contain its generated application password and salts, even when marked sensitive: restrict access to encrypted state, its version history and backups. Do not delete shared DNS zones, backends or unrelated resources.

Fixtures are synthetic and do not prove live cloud correctness. Offline checks never deploy resources. Reviewed dependency lockfiles may be committed.

## References

- [Terraform introduction](https://developer.hashicorp.com/terraform/intro)
- [Terraform module catalog](https://registry.terraform.io/browse/modules)
