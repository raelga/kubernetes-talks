# WordPress recovery with a managed instance group on GCP

This optional, **billable** lab compares [03-wordpress-module](../03-wordpress-module/README.md)'s single VM with a zonal managed instance group (MIG) whose desired size is one. This root uses the separate reusable [`wordpress-mig` module](../../../modules/gcp/wordpress-mig). A regional external TCP load balancer provides a stable HTTP endpoint; Cloud SQL holds the database, while uploaded files live on the VM's disposable disk. One VM and one database are **not** a highly available production service. There is no HTTPS or backup; use only disposable data.

## Prerequisites and deployment

Complete the [state bucket lab](../00-terraform-state/README.md) and review [GCP sign-in for Terraform](../README.md#sign-in-for-terraform). Use Terraform 1.10–1.x, the Google Cloud CLI, an approved billing-enabled project, and matching CLI and Application Default Credentials with access to the state bucket. Set `GOOGLE_CLOUD_PROJECT` to the intended project and check it before running `gcloud`. Enable Compute Engine, Cloud SQL Admin, Service Networking, Secret Manager and OS Login APIs. Your identity needs permissions to manage these resources, service accounts and secret-level IAM, attach the VM service account (`iam.serviceAccounts.actAs`), and use OS Login. Do not change organization policies to make the lab work.

Enable the required APIs in the approved project before applying (requires Service Usage permission):

```sh
gcloud services enable compute.googleapis.com sqladmin.googleapis.com servicenetworking.googleapis.com secretmanager.googleapis.com oslogin.googleapis.com --project="$GOOGLE_CLOUD_PROJECT"
```

Choose a unique resource prefix (3–27 lowercase letters, digits or hyphens, starting with a letter and ending with a letter or digit) and your current public IPv4 `/32`, including VPN/NAT. Both SSH and HTTP are restricted to the selected CIDR; update it if your address changes. Confirm quotas, private service address space and resource-name availability; Cloud SQL names may remain unavailable after deletion.

From the repository root, substitute values; the bucket name has no `gs://`:

```sh
cd course/infra/labs/gcp/04-wordpress-mig
terraform init -backend-config="bucket=STATE_BUCKET_NAME" -backend-config="prefix=gcp/wordpress-mig/DEPLOYMENT_ID"
terraform plan -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform apply -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform output
```

Review the plan before confirming. Defaults are region `us-west1` and zone `us-west1-b`; overrides must be compatible and used consistently for plan, apply and destroy. Use a different resource prefix and GCS state prefix for each deployment, including lab 03. Keep each initialized deployment in its own working directory; never migrate, overwrite or share another deployment's state. Retain the backend configuration for teardown. Cloud SQL, VM bootstrap and load balancer health checks can take several minutes.

## Compare recovery and data

The endpoint from `terraform output -raw url` is **HTTP only**. Avoid entering credentials over public HTTP: use OS Login to forward localhost to the current VM, and keep using `http://localhost:8080/` as the WordPress URL throughout the exercise. Anyone allowed through the firewall may initialize the site first; install it promptly using a disposable administrator account and password, never real data or credentials.

```sh
GROUP=$(terraform output -raw instance_group_name)
ZONE=$(terraform output -raw zone)
gcloud compute instance-groups managed list-instances "$GROUP" --zone="$ZONE"
```

Wait for a running instance, then replace `INSTANCE_NAME` below with its name from the listing. Keep this SSH session open while using the site:

```sh
gcloud compute ssh INSTANCE_NAME --zone="$ZONE" -- -L 8080:localhost:80
```

Visit <http://localhost:8080/> and complete installation. Publish a text post and upload a disposable image, adding it to the post. Confirm both are visible, then close the SSH session. Record the instance name and delete **that VM**, not the group or its Cloud SQL database:

```sh
gcloud compute instances delete INSTANCE_NAME --zone="$ZONE"
gcloud compute instance-groups managed list-instances "$GROUP" --zone="$ZONE"
```

Confirm the deletion when prompted. Refresh the listing until a replacement with a different name is running; bootstrap may require several more minutes. Do not use the managed group's `delete-instances` command for this experiment: it reduces the group's target size. Open a new SSH tunnel to the replacement using the same command and local port, then revisit <http://localhost:8080/>. The post and media-library database record remain in Cloud SQL, but the image file on the deleted VM disk is gone and the image no longer displays. The replacement starts with a fresh local filesystem. The load balancer URL remains stable, but availability can be interrupted while the replacement starts. Compare this with lab 03's standalone VM, which has no group to recreate it after deletion; do not delete lab 03's VM unless you intend to disrupt that separate deployment.

Terraform-generated database credentials and WordPress salts are stored in Secret Manager **and sensitive Terraform state**. Protect state, bucket versions, backups, plans, working directories and VM disks; never commit secrets or state. See [lab 02 security and troubleshooting](../02-wordpress/README.md#security-and-troubleshooting) for bootstrap context. Avoid publishing or sharing the temporary WordPress credentials.

## Destroy and review costs

In the same initialized directory, use exactly the same input values and any project, region and zone overrides:

```sh
terraform destroy -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Review and confirm the plan. This deletes this lab's group, VMs and disks, load balancer, database and its WordPress data, secrets and network; it does not delete the shared state bucket or lab 03. Confirm resources and external IPs are released in the console. Secret retention, state bucket versions and backups can retain sensitive data: remove only authorized lab artifacts under organizational policy. Keep the shared state bucket according to the [state lab](../00-terraform-state/README.md).

Review Cloud Billing reports and filters for Cloud SQL and storage, VM and disks, load balancing, external IPs, traffic, secrets and state storage/operations. Set or review approved budgets and alerts; billing can be delayed and budgets do **not** automatically stop spending. Check pricing before deployment; do not delete the shared project or billing account.
