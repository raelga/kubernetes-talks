# 02 · AWS: small, verifiable infrastructure that can be removed

**5 November 2026 · 18:00–21:00 · Rael Garcia · M2, with 60 integrated minutes of M1.**

The main student hands-on lab runs in **the assigned AWS Academy environment**, not a personal account. The goal is to read and modify prepared IaC, query resources with Python and destroy only what this exercise created. **This complete network/EC2/HTTP lab has not been tested against AWS.** An isolated S3 trial using the same Academy role verified creation of a private/encrypted bucket with enforced ownership, refresh with a no-change plan and destruction using `hashicorp/awscc` 1.108.0; that trial does not validate EC2, bootstrap, HTTP or Billing. Fixtures are **synthetic**, not evidence of a cloud execution.

## Scenario and boundaries

```text
Your IPv4 /32 ── HTTP:80 ── Internet Gateway ── subnet ── EC2 Ubuntu/Python
                                                        no SSH or IAM role
Temporary client credentials ── AWS API ── private, encrypted S3
```

Terraform creates a dedicated VPC and subnet, Internet Gateway, route table/route/association, security group, EC2 with an encrypted disk and an empty S3 bucket with complete public access blocking, AES256 and disabled ACLs. The server uses the Python standard library and systemd, **without Docker**. S3 does not host the website and EC2 does not access S3: they are separate resources queried from your authorized client. No IAM resources, key pair or instance profile are created or modified.

HTTP is plaintext: do not enter personal data, tokens or passwords. Only port 80 from your public IPv4 `/32` is allowed; SSH is not opened. Outbound TCP 80/443 allows Python installation from Ubuntu repositories, and outbound DNS is declared. There is no NAT Gateway, load balancer, Elastic IP or Kubernetes. The ephemeral public IP, disk, instance and traffic may incur costs; stopping EC2 does **not** remove its disks or clean up the exercise.

Every resource has `course=upc-2026`, `lab=cloud-02`, `lab_id=<your-identifier>`. Use a `lab_id` unique within the account, including across regions. By default the bucket name includes the account, identifier and a random 12-hexadecimal-character suffix stored in state: plans using the same state retain the name, while independent state generates another suffix. Only global storage receives this suffix; it does not replace network/VM isolation through `lab_id`. `bucket_name = "globally-available-name"` specifies an exact name without generating a suffix; `null` is the default. The custom name must be globally available: it does not adopt an existing bucket. Changing this variable may replace the bucket; review the plan and always use `bucket_name` from outputs for inventory/cleanup. Matching tags do not authorize deleting someone else's resources.

## Before class

- Academy access verified in session 1. The instructor confirms the actual lab type, region, Ubuntu 24.04 x86_64 AMI, allowed EC2 types and quotas; **there is no universal list valid for every Academy environment**.
- The instructor verifies AWS Cloud Control API permissions and the underlying S3 operations for `awscc_s3_bucket`, as well as EC2/network and inventory permissions. The official `hashicorp/awscc` provider manages the bucket through this supported API. `hashicorp/aws` 5.100.0 attempted to read `s3:GetBucketObjectLockConfiguration` for `aws_s3_bucket` without enabling Object Lock and encountered an SCP deny; the isolated Cloud Control trial completed the lifecycle with the same role, without IAM or SCP changes. There is no need to weaken that protection, but the result does not guarantee permissions in every Academy environment or replace the complete preflight.
- Terraform `>=1.6,<2`, Python `>=3.11`, AWS CLI v2, an editor and outbound connectivity to AWS and Ubuntu repositories. Python requires no external packages.
- Your own local working copy and state. Do not run from a shared state directory or the container environment retained for sessions 4–5.
- Temporary credentials supplied by the lab: configure the mechanism specified by Academy, including `AWS_SESSION_TOKEN` where applicable. Do not put credentials in HCL, user-data, Git, screenshots, AI prompts or exercise files. A named AWS profile is not required. Do not use `aws configure` to persist secrets when the environment specifies temporary variables.

All commands below run from `course/cloud-providers/labs/aws-iac`, relative to the repository root. Before using `python3`, check that it resolves to Python 3.11 or newer (some macOS system Python versions are older).

```sh
terraform version
python3 --version
aws --version
aws sts get-caller-identity --region us-east-1
```

The last call is **live and read-only**. Substitute the authorized region. Compare the account/identity with the assigned lab. If credentials have expired or you receive `AccessDenied`, stop and consult the actual instructions: do not try other people's accounts or relax policies. Offline mode below is a separate activity, not a silent replacement for the cloud result.

## 0–65 min · Read, plan, deploy

### 1. Read and configure

Identify in `main.tf` and `versions.tf`: resource references, `default_tags` for AWS-provider resources and equivalent explicit tags on `awscc_s3_bucket.private`, the official Canonical AMI, absence of IAM, `/32`, encrypted disk and S3 protections. The bucket and its three security configurations are declared together through AWS Cloud Control API; EC2/network and identity still use `hashicorp/aws`. `user-data.sh.tftpl` installs `python3` with apt and runs `app.py` as an unprivileged user with a limited capability to bind port 80. Public configuration is delivered as base64-encoded JSON, **not encrypted or secret**.

Copy `terraform.tfvars.example` to `terraform.tfvars` using your editor and change:

- `aws_region`: exactly the allowed region.
- `lab_id`: 3–20 lowercase characters, starting with a letter; e.g. `ana-red-01`. Do not use someone else's example.
- `client_cidr`: your public outbound IPv4 followed by `/32`, obtained through the instructor-authorized method. `203.0.113.10/32` is a **documentation address**, not a deployment address. VPN/NAT or changing networks may change this address. Your laptop's private IP is not suitable.
- `instance_type`: an allowed small type from the list validated in `variables.tf`. `t3.micro` is a starting value, **not a promise of availability or free usage**.
- `ami_id`: leave unset to find Canonical Ubuntu 24.04 x86_64. If Academy restricts the lookup, the instructor provides an authorized, compatible Ubuntu AMI in the region. Another distribution will not work with this apt/systemd bootstrap. Do not substitute an AMI to bypass restrictions.

### 2. Initialize and review without creating anything yet

```sh
terraform init
terraform workspace show
terraform validate
terraform plan -out=apply.tfplan
terraform show apply.tfplan
```

`init` downloads `hashicorp/aws` `>=5.80,<6` for identity/EC2/network, `hashicorp/awscc` `>=1.108,<2` for S3 and `hashicorp/random` `>=3.6,<4` for the suffix, and updates `.terraform.lock.hcl`; keep your working lockfile for reproducibility. Both AWS providers use `var.aws_region` and the authorized temporary credentials. This example uses **local state**, without a remote backend. Confirm that this is your directory/state and the `default` workspace intended for this exercise. Do not select another workspace because it contains shared resources.

`validate` checks configuration, **not permissions or budget**. `plan` does query APIs; review region, tags, type, `/32` source and that it does not import/destroy unrelated infrastructure. The outbound route `0.0.0.0/0` is expected: it is not an open SG ingress rule. Explain this difference before continuing. The saved plan contains configuration data: do not upload it.

### 3. Apply only the reviewed plan

```sh
terraform apply apply.tfplan
terraform output
terraform output -json > outputs.local.json
```

`apply` creates billable resources and must not run in an unauthorized account. If a variable changes, the previous plan does **not** include that change: generate and review a new one. Terraform finishes before apt/systemd are necessarily ready. Wait a few minutes and check HTTP during the Python block; do not add retries that conceal a broken service. SSH is not needed.

State contains identities and metadata needed to manage resources: retain it until cleanup completes. Do not publish `terraform.tfvars`, `outputs.local.json`, `.terraform/`, state, logs containing credentials or plans. Outputs `http_url`, `instance_id`, `bucket_name`, network IDs, account and disk let you verify this exact deployment.

## 65–125 min · M1: Python and AI-assisted review (60 minutes)

### A. Read data without credentials (15 min)

```sh
python3 inventory.py --fixture-dir fixtures --lab-id demo-aws --region us-east-1
```

This does not use AWS CLI or make HTTP requests. `fixtures/ec2.json` groups EC2 responses by operation and `fixtures/s3.json` groups tagging, blocking, encryption and ownership. Both declare `synthetic=true`; `fixtures/outputs.json` retains Terraform's `{name: {value, type, sensitive}}` format with invented IDs and documentation-reserved addresses. Output says `offline-synthetic-NO-CLOUD-VERIFICATION`, **never success in an AWS account**.

Read the shell-free `subprocess.run` call, tag filter list, `Reservations → Instances` unpacking and the distinction between an API error and an absent bucket in `inventory.py`. Identify why `AccessDenied` cannot mean “nothing remains”.

### B. Data failures and assisted review (25 min)

Make a local copy of `fixtures` named `fixtures-local` and edit **that copy**, not the originals:

1. Change `instances.Reservations[0].Instances[0].State.Name` from `running` to `stopped` in `ec2.json`.
2. Run the previous command with `--fixture-dir fixtures-local`; it must exit nonzero. In a shell, inspect the code with `echo $?` immediately afterward.
3. Restore `running`; empty `instances.Reservations`. Repeat: a missing instance must also fail.
4. Restore the data and change `BlockPublicPolicy` to `false` in `s3.json`. Repeat: incorrect security cannot count as success.
5. Restore everything; explain what changes if the JSON is invalid.

Ask AI, **using synthetic fixtures only**, to explain or propose a small presentation improvement (for example, displaying resource counts by type). Review the diff: preserve filters, explicit offline mode, nonzero failure, absence of mutations and JSON/HTTP validation. Manually compare against the three defective inputs before accepting its proposal. Do not request credentials or `except: pass`; do not turn “API inaccessible” into an empty list. Submit the reviewed snippet and reasoning, not a conversation containing secrets. This is a student modification; the base script is already functional.

### C. Compare with live AWS and the application (20 min)

With valid credentials and outputs from **your** `apply`:

```sh
python3 inventory.py --live --outputs outputs.local.json --lab-id YOUR-LAB-ID --region YOUR-REGION
python3 inventory.py --live --outputs outputs.local.json --lab-id YOUR-LAB-ID --region YOUR-REGION --probe-http
```

Replace both uppercase placeholders rather than copying them literally. The script checks the STS account, region, `lab_id`, `course/lab/lab_id` filters, exact instance/network/disk IDs, `running` state, association/route, IMDSv2, `/32` SG, encrypted disk and S3 protections. A stopped instance, missing expected resource, extra resource with your tags, denied API or malformed JSON produces a nonzero exit code. `--probe-http` adds an explicit 5-second request to the EC2 IP without proxies or redirects, comparing provider, message, lab_id and status. Without that option, inventory **does not prove the application responds**. It does not check every resource in the account: it examines exercise tags and the exact bucket saved in outputs.

EC2 `running` does not prove apt has finished. If HTTP fails, distinguish pending bootstrap, changed client public IP, route/SG and a dead service. The instructor can inspect **that EC2 instance's** system log in the console (Actions → Monitor and troubleshoot → Get system log); availability depends on the lab. Do not open SSH or grant a role to “fix it”. If bootstrap fails, correct the permitted cause and review replacement before applying.

You can also read and run the same app **locally**, without cloud or credentials:

```sh
python3 app.py --host 127.0.0.1 --port 8080
```

Visit `http://127.0.0.1:8080/` and `/health`; stop with Ctrl-C. Local mode uses `lab_id=local`; it is not EC2 evidence.

## 125–145 min · Change, reconciliation and controlled network failure

1. Change `message` to another public text in `terraform.tfvars`.
2. Run `terraform plan -out=change.tfplan` and `terraform show change.tfplan`. Bootstrap configuration changes and `user_data_replace_on_change=true` requests **EC2 replacement**: this is not a hot deployment. Predict the IP change and disk impact.
3. Apply only the reviewed plan: `terraform apply change.tfplan`. Regenerate `outputs.local.json` with `terraform output -json > outputs.local.json`, wait for bootstrap and repeat live inventory with HTTP. Verify the new message. A subsequent no-change plan should demonstrate convergence, not “reapply just in case”.
4. Inject a failure **only in your SG**: temporarily change `client_cidr` to documentation address `192.0.2.10/32`, review a `network.tfplan` plan and apply it. Save outputs again. Inventory without HTTP may be correct against the new configuration; `--probe-http` from your client must fail. This is an intentional connectivity failure, not a repaired service.
5. Restore your actual `/32`, generate/review/apply a new plan and save outputs again. Repeat the probe. Never use `0.0.0.0/0` to solve the failure.

If time is short, the instructor prioritizes the message change and demonstrates the `/32` failure; interpreting its cause and recovery is part of the wrap-up, not a requirement to expand the scenario.

## 145–165 min · AWS Billing, Cost Explorer and Budgets (20 min)

Do not expect a newly created session to appear instantly in billing. Follow the instructor-enabled console:

1. **Billing and Cost Management → Bills**: select month and account; locate EC2, EC2-Other/EBS, S3, public IPv4 and transfer according to the available classification. Distinguish instance hours, disk GiB-months, IPv4 hours, S3 requests/storage and traffic. An empty bucket does not imply zero total scenario cost.
2. **Cost Explorer → Cost and usage**: this week/month, daily granularity, unblended cost if available; group by service and filter by region. Add `course`, `lab`, `lab_id` tags when enabled as cost allocation tags. Activation and visibility may require permissions/time: they are not universally retroactive or a real-time resource inventory.
3. **Budgets → Create budget → Cost budget**: the instructor demonstrates an example monthly budget (e.g. USD 5, a teaching amount, **not a guarantee**), supported account/tag scope and actual-spend alerts at 50/80/100% and forecast alerts at 100%. Review the recipient email with its owner and, if a subscription requiring confirmation is created, its confirmation. Do not enter other people's addresses. Students do not create budgets or send notifications without permission; if the role prevents this, follow the instructor demonstration. No automatic budget action is configured.
4. Relate a cost filter to inventory, explain what a stopped EC2 would keep charging for and locate the subsequent `destroy`. An alert **does not automatically stop spending**. The Academy indicator does not guarantee a universal stop policy either: apply the actual lab rules.

If Academy denies Billing/Cost Explorer/Budgets, use the instructor's authorized screen or this **entirely synthetic sample** (not a current rate or invoice):

| Fictional day | Service/item | Region | Tags | Fictional cost USD |
|---|---|---|---|---:|
| 05/11 | EC2, compute time | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0.04 |
| 05/11 | EBS, storage | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0.01 |
| 05/11 | Public IPv4, hours | us-east-1 | unassigned in this sample | 0.01 |
| 05/11 | S3, requests | us-east-1 | upc-2026 / cloud-02 / demo-aws | 0.00 |

Group USD 0.06 by item, try the region filter and explain why filtering by tags could hide the unassigned row. Real cost estimates require checking prices for the intended region/type and duration; this table cannot establish free usage or measure your spending.

## 165–180 min · Destroy and check what remains

Do not press **Reset**, close a shared lab or delete the environment prepared for containers. Destroy only this exercise's local state, from the same directory and workspace:

```sh
terraform workspace show
terraform state list
terraform output -json > outputs.before-destroy.local.json
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
python3 inventory.py --live --outputs outputs.before-destroy.local.json --lab-id YOUR-LAB-ID --region YOUR-REGION --expect absent
terraform state list
```

The destruction plan must contain **only your cloud-02 resources**. Save the outputs file **beforehand**, because outputs disappear from state afterward. Do not use outputs from before an EC2 replacement: they contain old IDs and IPs. Retain state and outputs until deletion and verification finish successfully.

Verification queries the seven EC2 resource families using all three tags and the exact bucket. It tolerates EC2 still showing `terminated` instances, not `stopped` or `shutting-down`; it requires absence of your disk, VPC, subnet, gateway, table and SG. `NoSuchBucket` means S3 absence; `AccessDenied`, an expired token or a network error **mean failure, not cleanup**. If API consistency delays the result, wait and explicitly query again; do not change the script to return success. State must contain no resources; a locally empty list alone does not establish cloud cleanup.

The bucket starts empty. [`awscc_s3_bucket`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/s3_bucket) can only delete an empty bucket: it has no `force_destroy` attribute and does not automatically empty objects. If someone added objects, deletion fails; the instructor must review only that exact bucket and agree on explicit removal of those objects. There is no automatic bulk deletion. Do not delete state to hide resources or run `destroy` in another directory.

### Minimum evidence

- A short network/compute/storage and identity map; explanation of `/32`, private S3 and the absence of IAM on EC2.
- Sanitized excerpts from the initial plan and message-change replacement; justification of reconciliation.
- Offline result marked synthetic, injected failure and review of the AI proposal; separately identified live result, without secrets.
- Cost filters and alert design with limitations, distinguishing a sample from a live query.
- Destruction and subsequent query expecting `absent`; honestly documented permission incidents or pending resources. Do not publish plans/state/credentials as evidence.
