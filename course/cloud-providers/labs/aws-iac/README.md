# AWS: one web server, its network and private storage

Start with the [one-bucket Terraform demo](../terraform-intro/README.md#quick-path-one-bucket-with-local-state) if you only want to explain `plan → apply → destroy`.

This lab adds **one small EC2 web server and its own network**. Your computer reaches its HTTP endpoint through an Internet Gateway; port 80 accepts only your public IPv4 `/32`. A **separate private S3 bucket** demonstrates storage: it does not host the website, and the VM does not use it. There is no SSH, IAM role, container, load balancer or Kubernetes.

## 1. Check access and open the lab

Use authorized AWS credentials, your own working directory/local state and a unique `lab_id`. Confirm the allowed region, compatible Ubuntu AMI, small EC2 type, quotas and EC2/S3/Cloud Control permissions. Do not change IAM or account policies to bypass a denial.

From the repository root:

```sh
cd course/cloud-providers/labs/aws-iac
terraform version
python3 --version
aws --version
aws sts get-caller-identity --region us-east-1
```

Requirements: Terraform matching [versions.tf](versions.tf), Python `>=3.11` and AWS CLI v2. Substitute your authorized region and confirm the returned account/identity before continuing. Never put credentials or session tokens in these files or Git.

## 2. Configure your deployment

Copy `terraform.tfvars.example` to `terraform.tfvars` with your editor. Set:

- `aws_region`: your authorized region.
- `lab_id`: your own unique identifier, 3–20 lowercase letters/digits/hyphens, starting with a letter.
- `client_cidr`: your actual public outbound IPv4 followed by `/32`, not a private or documentation address. Never use `/0`.
- `instance_type`: a small permitted x86_64 type; `t3.micro` is not necessarily available or free.
- `ami_id`: leave unset for the configured Canonical image lookup, or use an explicitly authorized compatible AMI.

Keep `message` public and non-secret. Leave `bucket_name` unset for a generated unique name; a custom name must belong to a **new**, globally available bucket, not existing storage.

## 3. Read the plan before creating anything

```sh
terraform init
terraform workspace show
terraform validate
terraform plan -out=apply.tfplan
terraform show apply.tfplan
```

Confirm your intended local state/workspace and only these new resources: VPC, subnet, Internet Gateway, route table/association, restricted HTTP security group, EC2 with encrypted root disk and empty private S3, plus the name suffix. Check region, tags (`course`, `lab`, `lab_id`), `/32`, no SSH/IAM and S3 public blocking/encryption/disabled ACLs. A `0.0.0.0/0` **route** is expected; open ingress is not.

The lockfile selects the providers; `awscc` manages S3 through Cloud Control. `validate` checks configuration, not permissions or spending. Plans, local variables, state and outputs stay private.

## 4. Apply and look at AWS

```sh
terraform apply apply.tfplan
terraform output
terraform output -json > outputs.local.json
```

**Show this first:** locate your tagged EC2 instance and its VPC/subnet/security group in the console, then open the printed `http_url` from your authorized computer. Expect HTTP 200 and JSON containing `status: "ok"` and your `message`. The separate S3 bucket must remain private and empty.

EC2 `running` is not application readiness: wait for cloud-init. If HTTP fails, inspect that instance's system log and check bootstrap, your current outbound IP and the route/SG. Do not add SSH, grant an IAM role or widen ingress. The [lab guide](instructor-guide.md) covers verification and troubleshooting; reading the application source is not required to run this lab.

## 5. Change the message

Edit only `message` in `terraform.tfvars`, then:

```sh
terraform plan -out=change.tfplan
terraform show change.tfplan
terraform apply change.tfplan
terraform output -json > outputs.local.json
terraform output http_url
```

Review before applying: changed bootstrap configuration **replaces EC2**, not a hot update. The old root disk is deleted and IDs/public IP can change. Wait for the new bootstrap and open the **new URL**; verify the new message. Then run `terraform plan`: expect no changes.

## 6. Destroy only your resources and verify absence

Use the same directory, workspace and state. Do not reset a shared environment or delete resources outside this deployment.

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

Replace both uppercase placeholders. Review that the destruction plan contains **only your exercise resources**. Save the **latest** outputs before destruction, not outputs from before replacement. The read-only verifier checks ownership tags, the saved resource IDs and exact bucket; it requires network/disk/storage absence and accepts only `terminated` EC2, not a stopped instance. The final state list must be empty too. `AccessDenied`, expired credentials or query errors are **not proof of cleanup**.

Retain private state/outputs until cleanup is verified. The bucket has no automatic emptying or `force_destroy`: if objects were added, review that exact bucket with its owner. Never run recursive deletion or erase state to conceal resources. Small instances, disks, public IPv4 and traffic can cost money; stopping EC2 is not cleanup.

## Further checks

See the [lab guide](instructor-guide.md) for live HTTP verification, troubleshooting, the optional network-failure experiment and cost checks. Fixtures are synthetic, not cloud evidence. Billing data is delayed, and budget alerts do not automatically stop spending.
