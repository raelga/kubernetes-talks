# Cloud providers

Reusable cloud infrastructure and analysis labs. The guides preserve the teaching plan for UPC 2026–2027 sessions 2 and 3; they add neither classes nor final-project requirements.

| Lab | Walkthrough | Execution |
| --- | --- | --- |
| [AWS and IaC](labs/aws-iac/README.md) | Networking, VM, private storage, Terraform, Python inventory, diagnosis and cleanup | Students use the assigned AWS Academy lab, with permissions checked by the instructor |
| [Azure and GCP](labs/azure-gcp/README.md) | Transfer the same pattern, interpret differences and adapt queries | Instructor cloud demonstrations; student Python exercises use explicitly synthetic data without requiring Azure/GCP accounts |

Start with the standalone **[Terraform bucket and remote-state lab](../terraform/s3-state-intro/README.md)** before deploying networks and VMs. Two small buckets introduce the change workflow and migration to a dedicated state backend. This exercise does not automatically migrate the state of the cloud labs.

## Introductory references

Terraform is an Infrastructure as Code tool: describe desired resources in HCL, review proposed changes with `plan`, and execute approved changes with `apply`. Providers call service APIs; state links configuration to managed resources. Modules package reusable Terraform configuration.

- [What is Terraform?](https://developer.hashicorp.com/terraform/intro)
- [Terraform Registry — module catalog](https://registry.terraform.io/browse/modules)
- [Platform engineering — CNCF glossary](https://glossary.cncf.io/platform-engineering/)

## Before starting

1. Complete the AWS Academy access introduced in session 1. The instructor rehearses the lab with actual student permissions and confirms the region, allowed resources, quotas and time/budget limits.
2. Read the lab's `README.md` and `instructor-guide.md`: they distinguish real deployments, sample data, verification and cleanup. A synthetic-data run does not prove a cloud deployment works.
3. Install Terraform and Python as required by each lab. Live queries also need the provider CLI and an authenticated session. Never put credentials in examples.
4. Choose your own lab identifier rather than sharing names or Terraform state with other teams. Always review plans before applying or destroying.

## Security, costs and state

- Real deployments can incur charges. Fixture-based analysis exercises never deploy infrastructure automatically.
- Restrict HTTP to the authorized outbound client address; do not expose SSH to the Internet. The example object storage is private.
- Spend 15–20 minutes per provider on cost queries, filters, budgets/alerts and cleanup. Billing data can be delayed; budgets and alerts do not automatically stop spending. The Academy budget indicator is not a universal shutdown guarantee either.
- Destroy only the exercise resources using their original configuration and state. Do not reset Academy or delete shared infrastructure; preserve the teaching environment for the containers labs.
- Never commit states, plans, keys, private variables or real captures. Keep real captures in `real-captures/`, which Git ignores. State may contain sensitive data even when an output is marked sensitive.
- `.terraform.lock.hcl` records provider versions and checksums and can be committed after review. `.terraform/` is a local cache, not teaching material.

The guides document backends and locking where relevant. Do not share local state between students or invent a shared classroom backend without prior permissions and preparation.
