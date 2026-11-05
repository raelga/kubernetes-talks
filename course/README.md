# Infrastructure labs

Standalone labs for containers, Kubernetes and cloud infrastructure.

## Explore

- [Infrastructure](infra/README.md): Terraform basics, private EC2 behind an ALB, staged WordPress/MySQL and Azure/GCP comparison.
- [Terraform introduction on AWS: the state bucket](infra/labs/aws/terraform-intro/README.md): plan, apply and inspect one S3 bucket, then migrate its state from local to S3. Reuse this bucket for the EC2 and WordPress labs.
- [Terraform infrastructure examples](terraform/): existing environment and cluster configurations.
- [Containers](containers/README.md).
- [Kubernetes](kubernetes/README.md).

Lab documentation should be concise and reusable: prerequisites, execution, verification, troubleshooting and cleanup. Keep dates, teacher assignments, schedules and edition-specific requirements in the planning repository, not lab READMEs or guides. Keep technical constraints and operational safety waits where they are needed to run the lab.
