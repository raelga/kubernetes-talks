# Compute Engine basics: VM, startup and firewall

This lab creates billable resources in an approved project. For the course's offline alternative, use the [Azure/GCP comparison](../../azure-gcp/README.md).

Terraform creates a Debian VM, a VPC and subnet, and a firewall for SSH and HTTP from your chosen IP. A startup script serves a demo page on port 8080. The VM has a public IP; HTTP is unencrypted, so use no sensitive data.

## Prerequisites

- Install Terraform 1.10–1.x and the [Google Cloud CLI](../README.md). Windows also needs OpenSSH for `gcloud compute ssh`.
- Complete the [state bucket lab](../00-terraform-state/README.md). This lab uses the separate `gcp/compute-basics` state prefix.
- Use an approved, billing-enabled project with Compute Engine and OS Login APIs enabled. You need permissions to create and delete the resources, and OS Login permissions to connect.
- Find your public IPv4 address, including any VPN/NAT, and use `YOUR_PUBLIC_IP/32` below. Update it if your address changes.

## 1. Authenticate and initialize

Follow [project setup](../README.md) to select and verify the approved account and project. CLI authentication and Application Default Credentials (ADC) are separate. For this instructor demonstration, use your approved identity for both and verify the project; do not share credentials or browser links:

```sh
gcloud auth list
gcloud config get-value project
gcloud auth application-default login
```

From the repository root, enter the lab directory and initialize with the state bucket name from the state lab. Substitute the actual bucket name; do not include `gs://`. The backend uses ADC as well as the provider.

```sh
cd course/infra/labs/gcp/01-compute-basics/infra
terraform init -backend-config="bucket=STATE_BUCKET_NAME"
```

If changing the bucket for an existing working directory, follow Terraform's backend reconfiguration or migration prompts deliberately; do not accidentally reuse or overwrite another deployment's state.

## 2. Plan and deploy

Replace `PROJECT_ID` and `YOUR_PUBLIC_IP/32` with your approved project and public IP. The default is one standard (non-preemptible) `e2-micro` in Oregon: region `us-west1`, zone `us-west1-b`. If changing the location, pass matching region and zone variables to every command.

Google's [Compute Engine Free Tier](https://cloud.google.com/free/docs/free-cloud-features#compute) has eligibility and usage limits. A qualifying VM does not make the whole lab free: disk, external IP, network traffic and other usage can still incur charges. Check current pricing and billing.

```sh
terraform plan -var="project_id=PROJECT_ID" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform apply -var="project_id=PROJECT_ID" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Review the plan before confirming. The demo's fixed resource names require an unused lab namespace in the project. Once apply completes, print the URL and open it from the allowed network:

```sh
terraform output -raw application_url
```

Startup can take several minutes after Terraform reports creation. The page should say “Compute Engine basics”. The firewall is stateful; only the given source range can initiate connections to the two ports on the tagged VM. An organization firewall policy can still block them. HTTP is unencrypted, so do not enter secrets.

## 3. Connect and inspect

Use OS Login rather than manually sharing SSH private keys. `gcloud compute ssh` creates or uses a local SSH key, associates the public key with the authenticated OS Login identity and connects to the external IP. Confirm the account and project, and verify the host key fingerprint through a trusted channel before accepting an unfamiliar key. Do not use `--ssh-flag` options that disable host-key checking. On Windows, run this in PowerShell with OpenSSH installed; on macOS use Terminal. Substitute your project ID and, if changed, the selected zone:

```sh
gcloud compute ssh compute-basics-vm --project=PROJECT_ID --zone=us-west1-b
```

Inside the VM:

```sh
systemctl status compute-basics.service --no-pager
curl http://localhost:8080/
sudo journalctl -u google-startup-scripts.service --no-pager
exit
```

If the page is unavailable, check startup logs and `journalctl -u compute-basics.service --no-pager`, your public IP/CIDR, project policies and firewall. The startup script needs outbound access to Debian package repositories. SSH also requires the OS Login IAM permissions and TCP 22 from the allowed address. This lab does not configure IAP; connecting through IAP requires a different firewall design.

## 4. Destroy and review costs

Back in the local Terraform directory, destroy with the same variables (including any region/zone overrides), review the plan and confirm:

```sh
terraform destroy -var="project_id=PROJECT_ID" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Confirm in the console that the lab VM, its disk, external IP, firewall, subnet and network are gone. The shared state bucket is deliberately **not** destroyed; retain it according to the [state lab](../00-terraform-state/README.md). Review Cloud Billing costs and filters and the approved budgets/alerts, including VM, disk, external IP and network traffic. Billing can lag, and budgets do not automatically stop spending. Delete only resources created for this exercise; never delete the shared project or billing account.
