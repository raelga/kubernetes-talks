# Cloud provider labs

Use Terraform to explore cloud infrastructure, inspect what was created and clean it up.

| Lab | What you will do | Access |
| --- | --- | --- |
| [Terraform introduction](labs/terraform-intro/README.md) | Create a private S3 bucket, update a file and explore state | AWS credentials; remote-state migration is optional |
| [AWS](labs/aws-iac/README.md) | Deploy an HTTP VM, its network and separate private storage | Authorized AWS account |
| [Azure and GCP](labs/azure-gcp/README.md) | Compare provider responses and optionally deploy the same pattern | No account for fixtures; authorized accounts/backends for live deployments |

Start with the bucket-only Terraform path, then try the AWS web server. Keep the labs' directories and states separate. Use each README for commands and its companion guide for operational details.

## Run safely

1. Confirm the account, region, permissions, quotas and credential expiry before applying changes.
2. Use your own lab identifier and state. Never copy another deployment's state or overwrite existing resources.
3. Review every plan. Restrict HTTP to your authorized client address; do not add SSH, public storage or IAM exceptions to bypass failures.
4. Check costs, including disks, public IPs, requests and traffic. Billing can be delayed; budgets and alerts do not automatically stop spending.
5. Destroy only your resources and verify absence through the provider API as well as empty state. Do not reset shared environments.

Fixtures are synthetic and make no cloud calls. They do not prove a live deployment works. Real deployment commands can incur charges.

Keep credentials, private variables, state, plans and real captures out of Git. Store captures in ignored `real-captures/` directories; review provider lockfiles before committing them.

## Terraform references

- [What is Terraform?](https://developer.hashicorp.com/terraform/intro)
- [Terraform Registry — module catalog](https://registry.terraform.io/browse/modules)
