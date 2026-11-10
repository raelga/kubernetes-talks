# Compute Engine basics: VM, startup and firewall

This lab creates billable resources in an approved project. For the course's offline alternative, use the [Azure/GCP comparison](../../azure-gcp/README.md).

Terraform creates a Debian VM, a VPC and subnet, and a firewall for SSH and HTTP from your chosen IP. A startup script serves a demo page on port 8080. The VM has a public IP; HTTP is unencrypted, so use no sensitive data.

## Prerequisites

- Install Terraform 1.10–1.x and the [Google Cloud CLI](../README.md). Windows also needs OpenSSH for `gcloud compute ssh`.
- Complete the [state bucket lab](../00-terraform-state/README.md). This lab uses the separate `gcp/compute-basics` state prefix.
- Use an approved, billing-enabled project with Compute Engine and OS Login APIs enabled. You need permissions to create and delete the resources, and OS Login permissions to connect.
- Find your public IPv4 address, including any VPN/NAT, and use `YOUR_PUBLIC_IP/32` below. Update it if your address changes.

## 1. Authenticate and initialize

Complete the [Google Cloud bootstrap](../README.md#sign-in-for-terraform) in this terminal. Verify the active account and project before continuing. Terraform uses the project set in `GOOGLE_CLOUD_PROJECT`; repeat the bootstrap project step if you change projects.

From the repository root, enter the lab directory and initialize with the state bucket name from the state lab. Substitute the actual bucket name; do not include `gs://`. The backend uses ADC as well as the provider.

```sh
cd course/infra/labs/gcp/01-compute-basics/infra
terraform init -backend-config="bucket=STATE_BUCKET_NAME"
```

If changing the bucket for an existing working directory, follow Terraform's backend reconfiguration or migration prompts deliberately; do not accidentally reuse or overwrite another deployment's state.

## 2. Plan and deploy

Replace `YOUR_PUBLIC_IP/32` with your public IP. The default is one standard (non-preemptible) `e2-micro` in Oregon: region `us-west1`, zone `us-west1-b`. If changing the location, pass matching region and zone variables to every command.

Google's [Compute Engine Free Tier](https://cloud.google.com/free/docs/free-cloud-features#compute) has eligibility and usage limits. A qualifying VM does not make the whole lab free: disk, external IP, network traffic and other usage can still incur charges. Check current pricing and billing.

```sh
terraform plan -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform apply -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Review the plan before confirming. The demo's fixed resource names require an unused lab namespace in the project. Once apply completes, print the URL and open it from the allowed network:

```sh
terraform output -raw application_url
```

Startup can take several minutes after Terraform reports creation. The page should say “Compute Engine basics”. The firewall is stateful; only the given source range can initiate connections to the two ports on the tagged VM. An organization firewall policy can still block them. HTTP is unencrypted, so do not enter secrets.

## 3. Connect and inspect

Use OS Login rather than manually sharing SSH private keys. `gcloud compute ssh` creates or uses a local SSH key and associates its public key with your OS Login identity. Verify the active project and host key fingerprint before connecting. On Windows, use PowerShell with OpenSSH; on macOS, use Terminal. If you changed the zone, use that zone below:

```sh
gcloud compute ssh compute-basics-vm --zone=us-west1-b
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
terraform destroy -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Confirm in the console that the lab VM, its disk, external IP, firewall, subnet and network are gone. The shared state bucket is deliberately **not** destroyed; retain it according to the [state lab](../00-terraform-state/README.md). Review Cloud Billing costs and filters and the approved budgets/alerts, including VM, disk, external IP and network traffic. Billing can lag, and budgets do not automatically stop spending. Delete only resources created for this exercise; never delete the shared project or billing account.
